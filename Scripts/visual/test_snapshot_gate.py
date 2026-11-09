"""The snapshot gate workflow and its wiring into the release and dependency workflows (19-10; 19-CONTEXT D-15
amendment, D-16, D-19; 19-RESEARCH §5, §11).

PyYAML is not installed on this host, so the workflows are read through Ruby's Psych (`ruby -ryaml -rjson`), which
reads the `on` key as `true`, as YAML 1.1 does.
"""
import json
import os
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
WORKFLOWS = ROOT / '.github/workflows'
GATE = WORKFLOWS / 'snapshot-gate.yml'
SHARDS = ROOT / 'Scripts/visual/snapshot-shards.json'
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
        for kind in ('results.jsonl', 'shard.json', 'logs', 'actual', 'difference', 'reference'):
            self.assertIn(kind, results['with']['path'], name)
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
        self.assertEqual(len(self.plan['shards']), 20)
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

    def test_no_result_bundles_and_no_fault_switch(self):
        self.assertNotIn('xcresult', self.text)
        # The proof's fault switch lives only on the proof commit of ci/snapshot-gate (19-10 Task 4), where this
        # test runs in the gate's own `checks` job; everywhere else it must be absent (T-19-22).
        if os.environ.get('GITHUB_REF') == 'refs/heads/ci/snapshot-gate':
            self.skipTest('the proof branch carries the fault switch')
        for path in WORKFLOWS.glob('*.yml'):
            self.assertNotIn('EHPANDA_SNAPSHOT_FAULT', path.read_text(), path.name)


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
