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
ALLOWED_ACTIONS = ('actions/checkout@v7', 'actions/upload-artifact@v7', 'actions/download-artifact@v7',
                   'nick-fields/retry@v4')
JOBS = ('checks', 'build', 'shard', 'triage', 'retry', 'native-policy', 'aggregate')
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

    def test_it_has_the_seven_jobs(self):
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
        prefix = 'shard' if name == 'shard' else 'retry'
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

    def test_the_linux_jobs_download_only_the_small_shard_artifacts(self):
        for name in ('triage', 'aggregate'):
            patterns = [step['with'].get('pattern') for step in step_using(self.jobs[name], 'actions/download-artifact')]
            self.assertIn('shard-*', patterns, name)
            self.assertFalse([pattern for pattern in patterns if pattern and pattern.startswith('pictures')], name)

    def test_shard_timeouts_from_the_file_stay_within_the_limits(self):
        for shard in self.plan['shards']:
            self.assertLessEqual(shard['timeoutMinutes'], STEP_LIMIT, shard['id'])
        self.assertEqual(len({shard['id'] for shard in self.plan['shards']}), len(self.plan['shards']))
        self.assertLessEqual(max(shard['estimatedMinutes'] for shard in self.plan['shards']),
                             self.plan['targetMinutes'])
        build = runs(self.jobs['build'])
        self.assertIn('timeoutMinutes', build)

    def test_triage_and_aggregate_always_run(self):
        for name in ('triage', 'aggregate'):
            self.assertIn('always()', self.jobs[name]['if'], name)
        self.assertIn('snapshot_aggregate.py', runs(self.jobs['triage']))
        self.assertIn('--triage', runs(self.jobs['triage']))
        self.assertIn('shards', self.jobs['triage']['outputs'])

    def test_the_aggregate_is_the_verdict_and_includes_the_native_policy(self):
        aggregate = self.jobs['aggregate']
        self.assertEqual(set(aggregate['needs']), {'checks', 'build', 'shard', 'triage', 'retry', 'native-policy'})
        text = runs(aggregate)
        self.assertIn('snapshot_aggregate.py', text)
        self.assertIn('--retry', text)
        self.assertIn('--summary "$GITHUB_STEP_SUMMARY"', text)
        self.assertIn('snapshot_report.py', text)
        self.assertIn('needs.native-policy.result', self.text)
        self.assertNotIn('continue-on-error', aggregate)

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
        for name in ('shard', 'retry'):
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
        self.assertEqual(sorted(macos), ['build', 'native-policy', 'retry', 'shard'])
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
    - download-artifact@v7 with a pattern: each artifact goes into `<path>/<artifact name>`, except that every
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

    def run_step(self, step, temp, shard=None):
        env = {**os.environ, 'RUNNER_TEMP': str(temp), 'GITHUB_OUTPUT': str(temp / 'output'),
               'GITHUB_STEP_SUMMARY': str(temp / 'summary'), 'RUNNER_NAME': 'model', 'MODE': 'candidate'}
        env.pop('GITHUB_REF', None)
        for key, value in (step.get('env') or {}).items():
            env[key] = expand(str(value), temp, shard) if shard else str(value)
        script = expand(step['run'], temp, shard) if shard else step['run']
        subprocess.run(['bash', '-e', '-c', script], cwd=ROOT, env=env, check=True, capture_output=True, text=True)

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

    def linux_job(self, name, artifacts):
        temp = self.runner()
        for step in self.jobs[name]['steps']:
            if step.get('uses', '').startswith('actions/download-artifact'):
                self.download(step, temp, artifacts)
            elif 'run' in step and step.get('id') == name:
                self.run_step(step, temp)
        return temp

    def triage(self, artifacts):
        temp = self.linux_job('triage', artifacts)
        return [shard['id'] for shard in json.loads(self.outputs(temp)['shards'])]

    def aggregate(self, artifacts):
        temp = self.linux_job('aggregate', artifacts)
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

    def test_the_uploaded_results_leave_out_the_fetched_baseline(self):
        name, files = self.shard_job('shard', 's05', 1, 'drift')
        self.assertTrue(any(path.endswith('shard.json') for path in files), files)
        self.assertFalse([path for path in files if '.work' in path or 'baseline' in path], files)


class WiringTests(unittest.TestCase):
    def assert_release_gate(self, path):
        workflow = load(path)
        jobs = workflow['jobs']
        first = next(iter(jobs))
        gate = jobs[first]
        self.assertEqual(gate['uses'], './.github/workflows/snapshot-gate.yml', path.name)
        self.assertEqual(gate['with']['mode'], 'compare', path.name)
        self.assertEqual(gate['permissions'], {'contents': 'read'}, path.name)
        self.assertIn(first, [jobs['Deploy']['needs']] if isinstance(jobs['Deploy']['needs'], str)
                      else jobs['Deploy']['needs'], path.name)
        return gate, jobs['Deploy']

    def test_the_release_builds_only_after_the_gate(self):
        gate, deploy = self.assert_release_gate(WORKFLOWS / 'deploy.yml')
        # The gate runs only for the release the deploy job would make.
        self.assertEqual(re.sub(r'\s+', ' ', gate['if']).strip(), re.sub(r'\s+', ' ', deploy['if']).strip())

    def test_the_beta_builds_only_after_the_gate(self):
        self.assert_release_gate(WORKFLOWS / 'deploy-beta.yml')

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
