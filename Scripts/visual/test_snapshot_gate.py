"""The snapshot gate workflow and its wiring into the release and dependency workflows (19-10; 19-CONTEXT D-15
amendment, D-16, D-19; 19-RESEARCH §5, §11).

PyYAML is not installed on this host, so the workflows are read through Ruby's Psych (`ruby -ryaml -rjson`), which
reads the `on` key as `true`, as YAML 1.1 does.
"""
import fnmatch
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
WORKFLOWS = ROOT / '.github/workflows'
GATE = WORKFLOWS / 'snapshot-gate.yml'
SHARDS = ROOT / 'Scripts/visual/snapshot-shards.json'
ENVIRONMENT = ROOT / 'Scripts/visual/regression-environment.json'
INVENTORY = ROOT / 'AppPackage/Tests/VisualSnapshotTests/Resources/scenarios.json'
READ = ('y = YAML.respond_to?(:unsafe_load) ? YAML.unsafe_load(STDIN.read) : YAML.load(STDIN.read); '
        'print JSON.generate(y)')
# The majors already in use (19-RESEARCH §11); no new third-party action.
ALLOWED_ACTIONS = ('actions/checkout@v7', 'actions/upload-artifact@v7', 'actions/download-artifact@v8',
                   'nick-fields/retry@v4')
JOBS = ('checks', 'build', 'shard', 'triage', 'retry', 'triage2', 'retry2', 'triage3', 'retry3',
        'native-policy', 'aggregate')
JOB_LIMIT = 150
STEP_LIMIT = 120


def load(path):
    text = subprocess.run(['ruby', '-ryaml', '-rjson', '-e', READ], input=Path(path).read_text(),
                          capture_output=True, text=True, check=True).stdout
    return json.loads(text)


def triggers(workflow):
    return workflow.get('on', workflow.get('true'))


def runs(job):
    return '\n'.join(step.get('run', '') for step in job.get('steps', []))


def uses(job):
    return [step['uses'] for step in job.get('steps', []) if 'uses' in step]


def step_using(job, prefix):
    return [step for step in job.get('steps', []) if step.get('uses', '').startswith(prefix)]


class GateWorkflowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.gate = load(GATE)
        cls.jobs = cls.gate['jobs']
        cls.text = GATE.read_text()
        cls.plan = json.loads(SHARDS.read_text())

    def test_it_has_the_eleven_jobs(self):
        self.assertEqual(set(self.jobs), set(JOBS))

    def test_triggers_are_every_pull_request_dispatch_call_and_the_proof_branch(self):
        on = triggers(self.gate)
        self.assertIn('pull_request', on)
        self.assertNotIn('pull_request_target', on)
        self.assertFalse((on['pull_request'] or {}).get('branches'), 'every pull request, Dependabot included')
        for name in ('workflow_dispatch', 'workflow_call'):
            mode = on[name]['inputs']['mode']
            self.assertEqual(mode.get('default'), 'compare', name)
        self.assertEqual(on['workflow_dispatch']['inputs']['mode']['options'], ['compare', 'candidate'])
        self.assertEqual(on['push']['branches'], ['ci/snapshot-gate'])

    def test_the_mode_is_candidate_only_on_the_proof_branch_without_fingerprints(self):
        checks = runs(self.jobs['checks'])
        self.assertEqual(self.gate['env']['FINGERPRINTS'],
                         'AppPackage/Tests/VisualSnapshotTests/Baseline/fingerprints.json')
        self.assertIn('$FINGERPRINTS', checks)
        self.assertIn('candidate', checks)
        self.assertIn('no approved baseline yet', checks)
        self.assertIn('mode', self.jobs['checks']['outputs'])

    def test_pull_request_runs_cancel_superseded_ones_and_other_runs_have_their_own_group(self):
        concurrency = self.gate['concurrency']
        self.assertIn("github.event_name == 'pull_request'", concurrency['cancel-in-progress'])
        self.assertIn('github.event.pull_request.number', concurrency['group'])
        # Candidate, dispatched and release runs are keyed by their own run, so a pull request never cancels one.
        self.assertIn('github.run_id', concurrency['group'])
        self.assertIn('inputs.mode', concurrency['cancel-in-progress'])

    def test_checks_run_on_linux_with_the_python_tests_shard_check_and_totals(self):
        checks = self.jobs['checks']
        self.assertEqual(checks['runs-on'], 'ubuntu-latest')
        text = runs(checks)
        self.assertIn('python3 -m unittest discover', text)
        self.assertIn('snapshot_shards.py --check', text)
        self.assertIn('snapshot_matrix.py --totals', text)

    def test_build_runs_once_and_outputs_the_shard_list_from_the_shard_file(self):
        build = self.jobs['build']
        self.assertEqual(build['needs'], 'checks')
        text = runs(build)
        self.assertEqual(text.count('xcodebuild build-for-testing'), 2, 'the matrix and the UI test products')
        self.assertIn('-testPlan SnapshotMatrix', text)
        self.assertIn('-testPlan UITests', text)
        self.assertIn('snapshot-shards.json', text)
        self.assertIn('shards', build['outputs'])
        [upload] = step_using(build, 'actions/upload-artifact')
        self.assertEqual(upload['with']['retention-days'], 1)

    def assert_shard_matrix(self, name, source):
        job = self.jobs[name]
        self.assertIs(job['strategy']['fail-fast'], False, name)
        self.assertIs(job['continue-on-error'], True, name)
        self.assertEqual(job['strategy']['matrix']['shard'], '${{ fromJSON(%s) }}' % source, name)
        self.assertLessEqual(job['timeout-minutes'], JOB_LIMIT, name)
        [step] = [step for step in job['steps'] if 'run-shard.sh' in step.get('run', '')]
        self.assertEqual(step['timeout-minutes'], '${{ matrix.shard.timeoutMinutes }}', name)
        self.assertIn('--shard "${{ matrix.shard.id }}"', step['run'])
        # The results, the record, the logs and the failure triplets, small enough for the Linux jobs to read;
        # a candidate run's pictures go to their own artifact, which no later job downloads.
        uploads = {upload['with']['name']: upload for upload in step_using(job, 'actions/upload-artifact')}
        prefix = name
        results = uploads[f'{prefix}-${{{{ matrix.shard.id }}}}']
        pictures = uploads[f'pictures-{prefix}-${{{{ matrix.shard.id }}}}']
        self.assertEqual(set(uploads), {f'{prefix}-${{{{ matrix.shard.id }}}}',
                                        f'pictures-{prefix}-${{{{ matrix.shard.id }}}}'})
        self.assertEqual(results['if'], 'always()', name)
        self.assertNotIn('matrix.shard.family', results['with']['path'], name)
        self.assertIn('matrix.shard.family', pictures['with']['path'], name)
        # The results artifact is the packed folder (ArtifactLayoutTests); the pack step lists what goes in.
        [pack] = [step for step in job['steps'] if step.get('name') == 'Pack the results']
        self.assertEqual(pack['if'], 'always()', name)
        self.assertNotIn('matrix.shard.family', pack['run'], name)
        for kind in ('results.jsonl', 'shard.json', 'logs', 'actual', 'difference', 'reference'):
            self.assertIn(kind, pack['run'], name)
        self.assertIn("candidate", pictures['if'], name)
        for upload in uploads.values():
            self.assertEqual(upload['with']['retention-days'], 7, name)
            self.assertEqual(upload['with']['if-no-files-found'], 'ignore', name)
        return job, step

    def test_the_shard_matrix_never_cancels_or_decides_by_itself(self):
        job, step = self.assert_shard_matrix('shard', 'needs.build.outputs.shards')
        self.assertIn('--attempt 1', step['run'])

    def test_the_retry_runs_the_triage_list_once_and_is_skipped_when_it_is_empty(self):
        job, step = self.assert_shard_matrix('retry', 'needs.triage.outputs.shards')
        self.assertIn('--attempt 2', step['run'])
        self.assertIn("needs.triage.outputs.shards != '[]'", job['if'])
        self.assertIn('triage', job['needs'])

    def test_the_second_retry_runs_what_the_first_retry_did_not_bring_back_and_is_skipped_when_none(self):
        # Run 43298876957: the runner cut 3 of the 13 retries as it had cut 13 of the 27 shards. Round two lists the
        # shards whose latest artifact is still a shard-level error, and runs them as attempt 3.
        job, step = self.assert_shard_matrix('retry2', 'needs.triage2.outputs.shards')
        self.assertIn('--attempt 3', step['run'])
        self.assertIn("needs.triage2.outputs.shards != '[]'", job['if'])
        self.assertIn("needs.triage2.result == 'success'", job['if'])
        self.assertIn('!cancelled()', job['if'])
        self.assertEqual(set(job['needs']), {'checks', 'build', 'triage2'})
        triage = self.jobs['triage2']
        self.assertEqual(set(triage['needs']), {'build', 'shard', 'triage', 'retry'})
        self.assertIn('always()', triage['if'])
        self.assertIn("needs.build.result == 'success'", triage['if'])
        self.assertEqual(triage['runs-on'], 'ubuntu-latest')
        self.assertIn('shards', triage['outputs'])
        text = runs(triage)
        self.assertIn('snapshot_aggregate.py', text)
        self.assertIn('--triage --attempt 3', text)
        self.assertIn('--retry "$RUNNER_TEMP/retry"', text)
        patterns = {step['with'].get('pattern'): step['with']['path']
                    for step in step_using(triage, 'actions/download-artifact')}
        self.assertEqual(patterns, {'shard-*': '${{ runner.temp }}/results', 'retry-*': '${{ runner.temp }}/retry'})

    def test_the_third_retry_runs_what_the_second_did_not_bring_back_as_attempt_4(self):
        # Four attempts in all: by the same rule, `triage3` lists the shards still lost after `retry2` (`--attempt 4`).
        job, step = self.assert_shard_matrix('retry3', 'needs.triage3.outputs.shards')
        self.assertIn('--attempt 4', step['run'])
        self.assertIn("needs.triage3.outputs.shards != '[]'", job['if'])
        self.assertIn("needs.triage3.result == 'success'", job['if'])
        self.assertIn('!cancelled()', job['if'])
        self.assertEqual(set(job['needs']), {'checks', 'build', 'triage3'})
        triage = self.jobs['triage3']
        self.assertEqual(set(triage['needs']), {'build', 'shard', 'triage', 'retry', 'triage2', 'retry2'})
        self.assertIn('always()', triage['if'])
        self.assertIn("needs.build.result == 'success'", triage['if'])
        self.assertEqual(triage['runs-on'], 'ubuntu-latest')
        self.assertIn('shards', triage['outputs'])
        text = runs(triage)
        self.assertIn('--triage --attempt 4', text)
        self.assertIn('--retry "$RUNNER_TEMP/retry"', text)
        self.assertIn('--retry2 "$RUNNER_TEMP/retry2"', text)
        patterns = {step['with'].get('pattern'): step['with']['path']
                    for step in step_using(triage, 'actions/download-artifact')}
        self.assertEqual(patterns, {'shard-*': '${{ runner.temp }}/results', 'retry-*': '${{ runner.temp }}/retry',
                                    'retry2-*': '${{ runner.temp }}/retry2'})

    def test_every_retry_round_runs_the_same_steps_as_the_first(self):
        # The rounds differ in their attempt number, artifact names and matrix source, and in nothing else.
        def shape(name):
            text = json.dumps(self.jobs[name]['steps'], sort_keys=True)
            text = re.sub(r'(pictures-)?retry\d?-\$\{\{ matrix', r'\1R-${{ matrix', text)
            text = re.sub(r'--attempt \d', '--attempt N', text)
            return re.sub(r'attempt \d \((second |third )?retry\)', 'attempt N', text)
        for name in ('retry2', 'retry3'):
            self.assertEqual(shape('retry'), shape(name), name)
            for key in ('runs-on', 'timeout-minutes', 'continue-on-error', 'permissions', 'env'):
                self.assertEqual(self.jobs['retry'][key], self.jobs[name][key], (name, key))

    def test_the_linux_jobs_download_only_the_small_shard_artifacts(self):
        for name in ('triage', 'triage2', 'triage3', 'aggregate'):
            patterns = [step['with'].get('pattern') for step in step_using(self.jobs[name], 'actions/download-artifact')]
            self.assertIn('shard-*', patterns, name)
            self.assertFalse([pattern for pattern in patterns if pattern and pattern.startswith('pictures')], name)

    def test_shard_timeouts_from_the_file_stay_within_the_limits(self):
        for shard in self.plan['shards']:
            self.assertLessEqual(shard['timeoutMinutes'], STEP_LIMIT, shard['id'])
        self.assertEqual(len({shard['id'] for shard in self.plan['shards']}), len(self.plan['shards']))
        for shard in self.plan['shards']:
            self.assertLessEqual(shard['estimatedMinutes'], self.plan['targetMinutes'][shard['family']], shard['id'])
        build = runs(self.jobs['build'])
        self.assertIn('timeoutMinutes', build)

    def test_triage_and_aggregate_always_run(self):
        for name in ('triage', 'triage2', 'triage3', 'aggregate'):
            self.assertIn('always()', self.jobs[name]['if'], name)
        self.assertIn('snapshot_aggregate.py', runs(self.jobs['triage']))
        self.assertIn('--triage', runs(self.jobs['triage']))
        self.assertIn('shards', self.jobs['triage']['outputs'])

    def test_the_aggregate_is_the_verdict_and_includes_the_native_policy(self):
        aggregate = self.jobs['aggregate']
        self.assertEqual(set(aggregate['needs']), {'checks', 'build', 'shard', 'triage', 'retry', 'triage2', 'retry2',
                                                   'triage3', 'retry3', 'native-policy'})
        text = runs(aggregate)
        self.assertIn('snapshot_aggregate.py', text)
        self.assertIn('--retry', text)
        self.assertIn('--retry2 "$RUNNER_TEMP/retry2"', text)
        self.assertIn('--retry3 "$RUNNER_TEMP/retry3"', text)
        patterns = {step['with'].get('pattern'): step['with']['path']
                    for step in step_using(aggregate, 'actions/download-artifact')}
        self.assertEqual(patterns, {'shard-*': '${{ runner.temp }}/results', 'retry-*': '${{ runner.temp }}/retry',
                                    'retry2-*': '${{ runner.temp }}/retry2', 'retry3-*': '${{ runner.temp }}/retry3'})
        self.assertIn('"$RUNNER_TEMP"/retry2/*/reference', text)
        self.assertIn('"$RUNNER_TEMP"/retry3/*/reference', text)
        self.assertIn('--summary "$GITHUB_STEP_SUMMARY"', text)
        self.assertIn('snapshot_report.py', text)
        self.assertIn('needs.native-policy.result', self.text)
        self.assertNotIn('continue-on-error', aggregate)

    def test_a_dispatch_can_restrict_a_candidate_run_to_some_shards(self):
        # The dispatch input `shards`: comma-separated shard IDs of the plan, empty for all of them.
        on = triggers(self.gate)
        option = on['workflow_dispatch']['inputs']['shards']
        self.assertEqual(option['type'], 'string')
        self.assertEqual(option['default'], '')
        self.assertIsNot(option.get('required'), True)
        self.assertIn('candidate', option['description'])
        self.assertEqual(self.gate['env']['SHARD_IDS'], '${{ inputs.shards }}')
        checks = self.jobs['checks']
        [step] = [step for step in checks['steps'] if step.get('id') == 'selection']
        self.assertIn('snapshot_shards.py --select "$SHARD_IDS"', step['run'])
        self.assertEqual(step['env']['MODE'], '${{ steps.mode.outputs.mode }}')
        self.assertEqual(checks['outputs']['restricted'], '${{ steps.selection.outputs.restricted }}')
        names = [step.get('name') for step in checks['steps']]
        self.assertLess(names.index('Decide the mode'), names.index(step['name']))
        self.assertIn('SHARD_IDS', runs(self.jobs['build']))
        for name in ('triage', 'triage2', 'triage3', 'aggregate'):
            self.assertIn('--only "$SHARD_IDS"', runs(self.jobs[name]), name)

    def test_the_native_policy_belongs_to_no_shard_and_is_skipped_in_a_restricted_run(self):
        # It tests the devices' transitions, not a shard's pictures, so a run restricted to some shards leaves it out,
        # and the verdict of such a run is the aggregate's alone.
        self.assertEqual(self.jobs['native-policy']['if'], "needs.checks.outputs.restricted != 'true'")
        decide = next(step for step in self.jobs['aggregate']['steps'] if step.get('name') == 'Decide the run')
        self.assertEqual(decide['env']['RESTRICTED'], '${{ needs.checks.outputs.restricted }}')
        self.assertIn('"$RESTRICTED" != true', decide['run'])
        self.assertIn('"$POLICY" != success', decide['run'])

    def test_the_native_policy_runs_on_both_devices(self):
        job = self.jobs['native-policy']
        self.assertIs(job['strategy']['fail-fast'], False)
        self.assertEqual(sorted(entry['family'] for entry in job['strategy']['matrix']['include']), ['ipad', 'iphone'])
        self.assertIn('EhPandaUITests/NativeVisualPolicyUITests', runs(job))
        self.assertIn('hosted-simulator.sh create', runs(job))
        self.assertLessEqual(job['timeout-minutes'], JOB_LIMIT)

    def test_the_native_policy_runs_once_more_when_the_simulator_lost_it_and_keeps_both_logs(self):
        # Run 42577585956: the iPhone's test runner never finished bootstrapping and the policy failed with no test.
        job = self.jobs['native-policy']
        step = next(step for step in job['steps'] if step.get('id') == 'policy')
        self.assertIn('snapshot_infra.py --status "$status" "$RUNNER_TEMP/policy/xcodebuild-1.log"', step['run'])
        self.assertIn('policy 2', step['run'])
        self.assertEqual(step['run'].count('xcodebuild test-without-building'), 1)
        upload = next(step for step in job['steps'] if step.get('uses', '').startswith('actions/upload-artifact'))
        self.assertEqual(upload['if'], "failure() || steps.policy.outputs.retried == 'true'")
        self.assertEqual(
            upload['with']['path'].splitlines(),
            ['${{ runner.temp }}/policy/xcodebuild-*.log', '${{ runner.temp }}/policy/attempt-*.xcresult'],
        )
        self.assertIn('-resultBundlePath "$RUNNER_TEMP/policy/attempt-$1.xcresult"', step['run'])
        create = next(step for step in job['steps'] if 'hosted-simulator.sh create' in step.get('run', ''))
        self.assertLessEqual(create['timeout-minutes'] + step['timeout-minutes'], JOB_LIMIT - 10)

    def test_each_native_policy_attempt_starts_at_large_and_retries_a_failing_test_once(self):
        # Hosted run 3: a test that failed at AX5 left the simulator there for the next, and the plan's three
        # iterations of a 20-minute test outran the step.
        step = next(step for step in self.jobs['native-policy']['steps'] if step.get('id') == 'policy')
        policy = step['run'].split('policy() {', 1)[1].split('\n}', 1)[0]
        self.assertLess(policy.index('content_size large'), policy.index('xcodebuild test-without-building'))
        self.assertIn('xcrun simctl ui "$UDID" content_size large || return $?', policy)
        self.assertIn('-retry-tests-on-failure -test-iterations 2', policy)
        self.assertIn('-collect-test-diagnostics never', policy)

    def test_fail_fast_is_off_on_every_matrix(self):
        self.assertGreaterEqual(self.text.count('fail-fast: false'), 3)

    def test_every_job_has_minimal_explicit_permissions(self):
        self.assertEqual(self.gate.get('permissions'), {})
        for name, job in self.jobs.items():
            self.assertEqual(job.get('permissions'), {'contents': 'read'}, name)

    def test_only_the_actions_already_in_use(self):
        for name, job in self.jobs.items():
            for action in uses(job):
                self.assertIn(action, ALLOWED_ACTIONS, name)

    def test_the_macos_jobs_set_up_the_simulator_with_the_hosted_script(self):
        for name in ('shard', 'retry', 'retry2', 'retry3'):
            self.assertIn('Scripts/visual/run-shard.sh', runs(self.jobs[name]), name)
        self.assertNotIn('simctl create', self.text)

    def test_result_bundles_only_for_native_policy_and_no_fault_switch(self):
        # The native policy job alone keeps its result bundles, on failure: its failures are taps and waits that only
        # the bundle's screens and hierarchies show (hosted run 3).
        for name, job in self.jobs.items():
            if name != 'native-policy':
                self.assertNotIn('xcresult', json.dumps(job), name)
        # The proof's fault switch lives only on the proof commit of ci/snapshot-gate (19-10 Task 4), where this
        # test runs in the gate's own `checks` job; everywhere else it must be absent (T-19-22).
        if os.environ.get('GITHUB_REF') == 'refs/heads/ci/snapshot-gate':
            self.skipTest('the proof branch carries the fault switch')
        for path in WORKFLOWS.glob('*.yml'):
            self.assertNotIn('EHPANDA_SNAPSHOT_FAULT', path.read_text(), path.name)

    def test_every_macos_job_selects_the_pinned_xcode(self):
        # The image's default Xcode moved to 27.1 and every shard of run 42562780142 recorded drift; the image still
        # carries the pinned Xcode, under /Applications/Xcode_<version>.app.
        pinned = json.loads(ENVIRONMENT.read_text())['toolchain']['xcode']
        version = re.fullmatch(r'Xcode (\S+)\nBuild version \S+', pinned.strip()).group(1)
        expected = f'/Applications/Xcode_{version}.app/Contents/Developer'
        self.assertEqual(json.loads(ENVIRONMENT.read_text())['toolchain']['sdkVersion'], version)
        macos = [name for name, job in self.jobs.items() if job['runs-on'] != 'ubuntu-latest']
        self.assertEqual(sorted(macos), ['build', 'native-policy', 'retry', 'retry2', 'retry3', 'shard'])
        for name in macos:
            self.assertEqual(self.jobs[name].get('env', {}).get('DEVELOPER_DIR'), expected, name)


    def test_the_pinned_sdk_declares_every_api_the_app_checks_for(self):
        # An `#available(iOS 27.1, *)` branch calls API that only the 27.1 SDK declares (UIHingeInteraction,
        # `toolbarVerticalCompressionBehavior`, `axisBehavior`), so an older pinned Xcode cannot build the gate's app.
        sdk = json.loads(ENVIRONMENT.read_text())['toolchain']['sdkVersion']
        checks = []
        for folder in ('AppPackage/Sources', 'EhPanda', 'EhPandaUITests'):
            for path in sorted((ROOT / folder).rglob('*.swift')):
                for match in re.finditer(r'[#@]available\(iOS (\d+(?:\.\d+)*)', path.read_text()):
                    checks.append((tuple(int(part) for part in match.group(1).split('.')), path.name))
        newest, where = max(checks)
        self.assertGreaterEqual(tuple(int(part) for part in sdk.split('.')), newest,
                                f"{where} checks for iOS {'.'.join(map(str, newest))}; the pinned SDK is {sdk}")


def expand(text, temp, shard):
    for expression, value in (('${{ runner.temp }}', str(temp)), ('${{ matrix.shard.id }}', shard['id']),
                              ('${{ matrix.shard.family }}', shard['family'])):
        text = text.replace(expression, value)
    return text


class ArtifactLayoutTests(unittest.TestCase):
    """The shard results travel from the macOS jobs to `triage` and `aggregate` as artifacts. These tests play the
    workflow's own steps around a model of the two artifact actions, with one artifact and with several.

    - upload-artifact@v7: the artifact's root is the one directory given, the parent of the one file given, or the
      least common ancestor of several paths.
    - download-artifact@v8 with a pattern: each artifact goes into `<path>/<artifact name>`, except that every
      artifact goes into `<path>` itself when `merge-multiple` is set or when only one artifact matches. Run
      42562780142 unpacked its one retry, `retry-s11`, straight into `retry/`, and the aggregate never read it.
    """

    @classmethod
    def setUpClass(cls):
        cls.jobs = load(GATE)['jobs']
        cls.plan = {shard['id']: shard for shard in json.loads(SHARDS.read_text())['shards']}

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.temp = Path(self.directory.name)
        self.runners = 0

    def runner(self):
        self.runners += 1
        temp = self.temp / f'runner-{self.runners}'
        temp.mkdir()
        return temp

    def run_step(self, step, temp, shard=None, extra=None, check=True):
        env = {**os.environ, 'RUNNER_TEMP': str(temp), 'GITHUB_OUTPUT': str(temp / 'output'),
               'GITHUB_STEP_SUMMARY': str(temp / 'summary'), 'RUNNER_NAME': 'model', 'MODE': 'candidate',
               'SHARD_IDS': ''}
        env.pop('GITHUB_REF', None)
        for key, value in (step.get('env') or {}).items():
            env[key] = expand(str(value), temp, shard) if shard else str(value)
        env.update(extra or {})
        script = expand(step['run'], temp, shard) if shard else step['run']
        return subprocess.run(['bash', '-e', '-c', script], cwd=ROOT, env=env, check=check, capture_output=True,
                              text=True)

    def outputs(self, temp):
        path = temp / 'output'
        lines = path.read_text().splitlines() if path.is_file() else []
        return dict(line.split('=', 1) for line in lines if '=' in line)

    def shard_job(self, job_name, shard_id, attempt, infra):
        """Plays one shard or retry job whose run step recorded `infra`, or left nothing when `infra` is None (a
        lost runner, or the proof's `no-artifact`); returns `(artifact name, files)`, files `None` for no
        artifact."""
        job = self.jobs[job_name]
        shard = self.plan[shard_id]
        temp = self.runner()
        out = temp / 'shard' / shard_id
        if infra is not None:
            (out / 'logs').mkdir(parents=True)
            (out / 'logs' / 'fetch.log').write_text('model\n')
            (temp / 'shard' / f'{shard_id}.work' / 'baseline').mkdir(parents=True)
            (temp / 'shard' / f'{shard_id}.work' / 'baseline' / 'x.png').write_bytes(b'baseline')
            subprocess.run(['python3', str(ROOT / 'Scripts/visual/snapshot_shard.py'), 'record', '--shards',
                            str(SHARDS), '--inventory', str(INVENTORY), '--environment', str(ENVIRONMENT),
                            '--shard', shard_id, '--out', str(out / 'shard.json'), '--mode', 'candidate',
                            '--attempt', str(attempt), '--infra', infra, '--detail', 'model'],
                           check=True, capture_output=True, text=True)
        steps = job['steps']
        start = next(index for index, step in enumerate(steps) if 'run-shard.sh' in step.get('run', ''))
        upload = next(step for step in steps if step.get('uses', '').startswith('actions/upload-artifact')
                      and not step['with']['name'].startswith('pictures'))
        for step in steps[start + 1:steps.index(upload)]:
            if 'run' in step:
                self.run_step(step, temp, shard)
        return expand(upload['with']['name'], temp, shard), self.upload(upload, temp, shard)

    def upload(self, step, temp, shard):
        lines = [expand(line.strip(), temp, shard) for line in step['with']['path'].splitlines() if line.strip()]
        includes = [Path(line) for line in lines if not line.startswith('!')]
        excludes = [line[1:] for line in lines if line.startswith('!')]
        for path in includes:
            self.assertFalse(set('*?[') & set(str(path)), f'the model takes no wildcard in an included path: {path}')
        files = []
        for path in includes:
            if path.is_dir():
                files += sorted(item for item in path.rglob('*') if item.is_file())
            elif path.is_file():
                files.append(path)
        files = [item for item in files
                 if not any(fnmatch.fnmatch(str(part), pattern) for pattern in excludes for part in (item, *item.parents))]
        if not files:
            return None
        if len(includes) == 1:
            root = includes[0] if includes[0].is_dir() else includes[0].parent
        else:
            root = Path(os.path.commonpath([str(path) for path in includes]))
        return {str(item.relative_to(root)): item.read_bytes() for item in files}

    def download(self, step, temp, artifacts):
        options = step['with']
        target = Path(options['path'].replace('${{ runner.temp }}', str(temp)))
        merge = str(options.get('merge-multiple', False)).lower() == 'true'
        matched = {name: files for name, files in artifacts.items()
                   if files is not None and fnmatch.fnmatch(name, options['pattern'])}
        for name, files in matched.items():
            destination = target if merge or len(matched) == 1 else target / name
            for relative, data in files.items():
                (destination / relative).parent.mkdir(parents=True, exist_ok=True)
                (destination / relative).write_bytes(data)

    def linux_job(self, name, artifacts, ids=''):
        temp = self.runner()
        for step in self.jobs[name]['steps']:
            if step.get('uses', '').startswith('actions/download-artifact'):
                self.download(step, temp, artifacts)
            elif 'run' in step and step.get('id') == name:
                self.run_step(step, temp, extra={'SHARD_IDS': ids})
        return temp

    def triage(self, artifacts, job='triage', ids=''):
        temp = self.linux_job(job, artifacts, ids)
        return [shard['id'] for shard in json.loads(self.outputs(temp)['shards'])]

    def aggregate(self, artifacts, ids=''):
        temp = self.linux_job('aggregate', artifacts, ids)
        return json.loads((temp / 'gate' / 'aggregate.json').read_text())

    def first_attempts(self, lost=(), only=None):
        artifacts = {}
        for shard_id in self.plan:
            if only is not None and shard_id not in only:
                continue
            name, files = self.shard_job('shard', shard_id, 1, None if shard_id in lost else 'drift')
            artifacts[name] = files
        return artifacts

    def test_one_shard_artifact_is_read_as_that_shard(self):
        artifacts = self.first_attempts(only={'s05'})
        self.assertEqual(sorted(artifacts), ['shard-s05'])
        self.assertEqual(self.triage(artifacts), [shard for shard in self.plan if shard != 's05'])
        document = self.aggregate(artifacts)
        self.assertEqual(document['counts']['drift'], 1)
        self.assertEqual(document['counts']['infrastructureErrors'], len(self.plan) - 1)

    def test_several_shard_artifacts_are_read_as_their_shards(self):
        artifacts = self.first_attempts(lost={'s11', 's12'})
        self.assertEqual(self.triage(artifacts), ['s11', 's12'])
        document = self.aggregate(artifacts)
        self.assertEqual(document['counts']['drift'], len(self.plan) - 2)
        self.assertEqual(document['counts']['infrastructureErrors'], 2)

    def test_one_retry_artifact_is_read_as_that_shards_second_attempt(self):
        artifacts = self.first_attempts(lost={'s11'})
        self.assertEqual(self.triage(artifacts), ['s11'])
        name, files = self.shard_job('retry', 's11', 2, 'drift')
        artifacts[name] = files
        document = self.aggregate(artifacts)
        self.assertEqual(document['shards']['s11']['attempt'], 2)
        self.assertEqual(document['counts']['drift'], len(self.plan))
        self.assertEqual(document['counts']['infrastructureErrors'], 0)

    def test_several_retry_artifacts_are_read_as_their_second_attempts(self):
        artifacts = self.first_attempts(lost={'s03', 's11'})
        self.assertEqual(self.triage(artifacts), ['s03', 's11'])
        for shard_id in ('s03', 's11'):
            name, files = self.shard_job('retry', shard_id, 2, 'drift')
            artifacts[name] = files
        document = self.aggregate(artifacts)
        self.assertEqual([document['shards'][shard]['attempt'] for shard in ('s03', 's11')], [2, 2])
        self.assertEqual(document['counts']['drift'], len(self.plan))
        self.assertEqual(document['counts']['infrastructureErrors'], 0)

    def test_the_second_retry_lists_only_the_shards_the_first_retry_did_not_bring_back(self):
        artifacts = self.first_attempts(lost={'s03', 's11', 's12'})
        self.assertEqual(self.triage(artifacts), ['s03', 's11', 's12'])
        # s03's retry came back, s11's was cut with no shard.json, s12's left no artifact at all.
        for shard_id, infra in (('s03', 'drift'), ('s11', None)):
            name, files = self.shard_job('retry', shard_id, 2, infra)
            artifacts[name] = files
        self.assertEqual(self.triage(artifacts, 'triage2'), ['s11', 's12'])

    def test_the_second_retry_artifact_is_read_as_that_shards_third_attempt(self):
        artifacts = self.first_attempts(lost={'s03', 's11'})
        for shard_id in ('s03', 's11'):
            name, files = self.shard_job('retry', shard_id, 2, None)
            artifacts[name] = files
        self.assertEqual(self.triage(artifacts, 'triage2'), ['s03', 's11'])
        name, files = self.shard_job('retry2', 's11', 3, 'drift')
        self.assertEqual(name, 'retry2-s11')
        artifacts[name] = files
        document = self.aggregate(artifacts)
        self.assertEqual(document['shards']['s11']['attempt'], 3)
        self.assertEqual(document['shards']['s03']['attempt'], 1)
        self.assertEqual(document['counts']['drift'], len(self.plan) - 1)
        self.assertEqual(document['counts']['infrastructureErrors'], 1)

    def test_the_third_retry_lists_what_the_second_did_not_bring_back_and_is_read_as_attempt_4(self):
        artifacts = self.first_attempts(lost={'s03', 's11', 's12'})
        for shard_id in ('s03', 's11', 's12'):
            name, files = self.shard_job('retry', shard_id, 2, None)
            artifacts[name] = files
        # The second retry brought s03 back, was cut with no shard.json for s11, and left nothing for s12.
        name, files = self.shard_job('retry2', 's03', 3, 'drift')
        artifacts[name] = files
        name, files = self.shard_job('retry2', 's11', 3, None)
        artifacts[name] = files
        self.assertEqual(self.triage(artifacts, 'triage3'), ['s11', 's12'])
        name, files = self.shard_job('retry3', 's12', 4, 'drift')
        self.assertEqual(name, 'retry3-s12')
        artifacts[name] = files
        document = self.aggregate(artifacts)
        self.assertEqual(document['shards']['s12']['attempt'], 4)
        self.assertEqual(document['shards']['s03']['attempt'], 3)
        self.assertEqual(document['counts']['drift'], len(self.plan) - 1)

    def test_a_retry_artifact_is_not_taken_for_a_second_retry_or_the_other_way_round(self):
        artifacts = self.first_attempts(lost={'s11'})
        name, files = self.shard_job('retry', 's11', 2, 'drift')
        artifacts[name] = files
        document = self.aggregate(artifacts)
        self.assertEqual(document['shards']['s11']['attempt'], 2)
        artifacts = self.first_attempts(lost={'s11'})
        name, files = self.shard_job('retry2', 's11', 3, 'drift')
        artifacts[name] = files
        self.assertEqual(self.aggregate(artifacts)['shards']['s11']['attempt'], 3)

    def selection(self, ids, mode='candidate'):
        step = next(step for step in self.jobs['checks']['steps'] if step.get('id') == 'selection')
        temp = self.runner()
        result = self.run_step(step, temp, extra={'SHARD_IDS': ids, 'MODE': mode}, check=False)
        return result, self.outputs(temp)

    def test_the_checks_accept_a_known_selection_and_say_the_run_is_restricted(self):
        result, outputs = self.selection('s19, s01')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(outputs, {'restricted': 'true'})
        for mode in ('candidate', 'compare'):
            result, outputs = self.selection('', mode)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(outputs, {'restricted': 'false'})

    def test_the_checks_refuse_an_unknown_shard_and_a_restricted_compare_run(self):
        result, outputs = self.selection('s01,s99')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('s99', result.stdout + result.stderr)
        self.assertEqual(outputs, {})
        result, outputs = self.selection('s01', 'compare')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('candidate', result.stdout + result.stderr)

    def test_the_matrix_holds_only_the_selected_shards(self):
        step = next(step for step in self.jobs['build']['steps'] if step.get('id') == 'shards')
        for ids, expected in (('', list(self.plan)), ('s40, s01,s40', ['s01', 's40'])):
            temp = self.runner()
            self.run_step(step, temp, extra={'SHARD_IDS': ids})
            matrix = json.loads(self.outputs(temp)['shards'])
            self.assertEqual([shard['id'] for shard in matrix], expected)
            self.assertTrue(all(set(shard) == {'id', 'family', 'timeoutMinutes'} for shard in matrix))
            self.assertEqual({shard['id']: shard['family'] for shard in matrix},
                             {shard: self.plan[shard]['family'] for shard in expected})

    def test_a_restricted_run_triages_and_aggregates_only_the_selected_shards(self):
        artifacts = self.first_attempts(lost={'s11'}, only={'s05', 's11'})
        self.assertEqual(self.triage(artifacts, ids='s05,s11'), ['s11'])
        self.assertEqual(self.triage(artifacts, ids='s05'), [])
        self.assertEqual(self.triage(artifacts, 'triage3', ids='s05'), [])
        document = self.aggregate(artifacts, ids='s05,s11')
        self.assertEqual(sorted(document['shards']), ['s05', 's11'])
        self.assertEqual(document['counts']['drift'], 1)
        self.assertEqual(document['counts']['infrastructureErrors'], 1)
        document = self.aggregate(artifacts, ids='s05')
        self.assertEqual((document['counts']['drift'], document['counts']['infrastructureErrors']), (1, 0))

    def test_the_uploaded_results_leave_out_the_fetched_baseline(self):
        name, files = self.shard_job('shard', 's05', 1, 'drift')
        self.assertTrue(any(path.endswith('shard.json') for path in files), files)
        self.assertFalse([path for path in files if '.work' in path or 'baseline' in path], files)


class WiringTests(unittest.TestCase):
    # Snapshot gate off for 3.0 (owner msg 3757): the release workflows neither call the gate nor wait for it.
    # The gate itself is still run by pull requests, dispatches and dependency updates.
    def assert_gate_off(self, path):
        workflow = load(path)
        for name, job in workflow['jobs'].items():
            self.assertNotIn('uses', job, f'{path.name}: {name}')
            self.assertNotIn('needs', job, f'{path.name}: {name}')
        text = path.read_text(encoding='utf-8')
        body = '\n'.join(line for line in text.splitlines() if not line.strip().startswith('#'))
        for needle in ('snapshot-gate.yml', 'require-snapshot-gate'):
            self.assertNotIn(needle, body, path.name)
        return workflow

    def test_the_release_does_not_wait_for_the_gate(self):
        workflow = self.assert_gate_off(WORKFLOWS / 'deploy.yml')
        self.assertEqual(list(workflow['jobs']), ['Deploy'])

    def test_the_beta_does_not_wait_for_the_gate(self):
        workflow = self.assert_gate_off(WORKFLOWS / 'deploy-beta.yml')
        self.assertEqual(list(workflow['jobs']), ['Deploy'])

    def test_the_pal_submission_does_not_wait_for_the_gate(self):
        self.assert_gate_off(WORKFLOWS / 'deploy-pal.yml')

    def test_the_gate_stays_callable_for_pull_requests_and_dispatches(self):
        gate = load(WORKFLOWS / 'snapshot-gate.yml')
        self.assertIn('aggregate', gate['jobs'])

    def test_dependency_updates_dispatch_the_gate_on_their_branch(self):
        workflow = load(WORKFLOWS / 'dependencies.yml')
        self.assertEqual(workflow['permissions'].get('actions'), 'write')
        steps = workflow['jobs']['dependencies']['steps']
        names = [step.get('uses', '') for step in steps]
        create = next(index for index, name in enumerate(names) if name.startswith('peter-evans/create-pull-request'))
        self.assertTrue(steps[create].get('id'))
        dispatch = [index for index, step in enumerate(steps) if 'gh workflow run snapshot-gate.yml' in step.get('run', '')]
        self.assertEqual(len(dispatch), 1)
        self.assertGreater(dispatch[0], create)
        step = steps[dispatch[0]]
        self.assertIn('--ref update-dependencies', step['run'])
        self.assertIn('mode=compare', step['run'])
        self.assertIn(steps[create]['id'], step['if'])


if __name__ == '__main__':
    unittest.main()
