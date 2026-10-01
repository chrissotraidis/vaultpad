#!/usr/bin/env python3
"""Exercise the actual device-build script with synthetic files and a compiler stub."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class DeviceBuildJobsTests(unittest.TestCase):
    def test_install_guide_keeps_the_existing_unsigned_preview_visible(self):
        guide = (ROOT / "docs/INSTALL.md").read_text()
        self.assertIn("Unsigned preview available", guide)
        self.assertIn("building from source is optional", guide)
        self.assertIn("https://github.com/chrissotraidis/vaultpad/releases/tag/v0.1.0-preview.1", guide)
        self.assertIn("shasum -a 256 -c VaultPad-0.1.0-preview.1-unsigned.ipa.sha256", guide)
        self.assertNotIn("Downloads retired", guide)
        self.assertNotIn("latest GitHub release (retired)", guide)

    def run_build(self, jobs=None, configuration="Release"):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            scripts = root / "scripts"
            scripts.mkdir()
            shutil.copy2(ROOT / "scripts/build-device.sh", scripts / "build-device.sh")
            helpers = root / "helpers-ran"
            for name in ("build-ce-dat.sh", "configure.sh"):
                script = scripts / name
                script.write_text("#!" + sys.executable + "\n"
                                  "import os, pathlib\n"
                                  "pathlib.Path(os.environ['VAULTPAD_TEST_HELPERS']).touch()\n")
                script.chmod(0o755)
            binary_dir = root / "bin"
            binary_dir.mkdir()
            compiler = binary_dir / "xcodebuild"
            compiler.write_text("#!" + sys.executable + "\n"
                                "import json, os, pathlib, sys\n"
                                "pathlib.Path(os.environ['VAULTPAD_TEST_ARGS']).write_text(json.dumps(sys.argv[1:]))\n")
            compiler.chmod(0o755)
            app = root / "out/build/engine-ios-device" / (configuration + "-iphoneos") / "fallout2-ce.app"
            app.mkdir(parents=True)
            executable = app / "fallout2-ce"
            executable.write_text("synthetic executable\n")
            executable.chmod(0o755)
            resource = root / "engine/out/build/macos/ce.dat"
            resource.parent.mkdir(parents=True)
            resource.write_text("synthetic resource\n")
            for name in ("LICENSE.md", "THIRD_PARTY_NOTICES.md"):
                (root / name).write_text("synthetic notice\n")
            recorded = root / "compiler-args.json"
            env = dict(os.environ, PATH=str(binary_dir) + os.pathsep + os.environ["PATH"],
                       VAULTPAD_TEST_ARGS=str(recorded), VAULTPAD_TEST_HELPERS=str(helpers))
            env.pop("CMAKE_BUILD_PARALLEL_LEVEL", None)
            if jobs is not None:
                env["CMAKE_BUILD_PARALLEL_LEVEL"] = jobs
            result = subprocess.run(["/bin/bash", str(scripts / "build-device.sh"), configuration],
                                    env=env, capture_output=True, text=True)
            args = json.loads(recorded.read_text()) if recorded.exists() else None
            return result, args, helpers.exists()

    def test_padmint_limit_reaches_the_real_command(self):
        result, args, _ = self.run_build("2")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(args[:2], ["-jobs", "2"])
        self.assertIn("CODE_SIGNING_ALLOWED=NO", args)
        self.assertIn("CODE_SIGNING_REQUIRED=NO", args)
        self.assertEqual(args[-1], "build")

    def test_unset_keeps_the_existing_manual_default(self):
        result, args, _ = self.run_build()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("-jobs", args)

    def test_empty_keeps_the_existing_manual_default(self):
        result, args, _ = self.run_build("")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("-jobs", args)

    def test_configuration_and_platform_are_preserved(self):
        result, args, _ = self.run_build("1", "Debug")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(args[args.index("-configuration") + 1], "Debug")
        self.assertEqual(args[args.index("-sdk") + 1], "iphoneos")
        self.assertEqual(args[args.index("-arch") + 1], "arm64")

    def test_invalid_limit_stops_before_helpers_or_compilation(self):
        for value in ("0", "-1", "two", "2 extra", "1; echo bad", "02"):
            with self.subTest(value=value):
                result, args, helpers_ran = self.run_build(value)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("must be a positive integer", result.stderr)
                self.assertIsNone(args)
                self.assertFalse(helpers_ran)


if __name__ == "__main__":
    unittest.main()
