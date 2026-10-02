"""Require the existing PadMint content check before CI uploads the app."""
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]


class CIContentGateTests(unittest.TestCase):
    def test_content_check_blocks_the_upload(self):
        workflow = (ROOT / '.github/workflows/ci.yml').read_text()
        command = 'python3 -B -m padmint audit "$GITHUB_WORKSPACE/out/release/VaultPad-0.1.0-unsigned.ipa"'
        self.assertIn(command, workflow)
        self.assertLess(workflow.index(command),
                        workflow.index('uses: actions/upload-artifact@'))
        gate = workflow[workflow.index('- name: Audit the IPA before upload'):
                        workflow.index('- uses: actions/upload-artifact@')]
        self.assertNotIn('continue-on-error', gate)
        self.assertNotIn('||', gate)

    def test_auditor_is_pinned_and_build_checks_remain(self):
        workflow = (ROOT / '.github/workflows/ci.yml').read_text()
        self.assertRegex(workflow, re.compile(
            r'repository: chrissotraidis/padmint\s+'
            r'ref: f0efbb738cac934559e986143343dc8720a6fb1d\s+'
            r'path: \.ci-padmint'))
        for command in ('./scripts/verify-repository.sh',
                        './scripts/build-simulator.sh Release',
                        './scripts/package-release.sh 0.1.0 Release'):
            self.assertIn(command, workflow)


if __name__ == '__main__':
    unittest.main()
