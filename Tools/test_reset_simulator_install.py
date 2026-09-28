#!/usr/bin/env python3
"""Exercise deployment cleanup on disposable files, without invoking a build."""
from pathlib import Path
import subprocess
import tempfile
import unittest

RESET = Path(__file__).with_name('reset_simulator_install.sh')


class ResetSimulatorInstallTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='simulator-install-test-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()

    def create(self, name):
        path = self.root / name
        path.write_bytes(b'previous content')
        return path

    def reset(self):
        return subprocess.run(['/bin/sh', str(RESET), str(self.root)],
                              capture_output=True, text=True)

    def test_removes_all_old_starters_binary_and_orphaned_sidecars(self):
        names = ['LibertyLineSimulator']
        for version in ['1.0.1', '1.0.190']:
            names.extend(f'liberty-line-simulator-{version}.sqlite{suffix}'
                         for suffix in ['', '-wal', '-shm', '-journal'])
        names.append('liberty-line-simulator-1.0.2.sqlite-wal')
        for name in names:
            self.create(name)
        result = self.reset()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(list(self.root.iterdir()), [])
        self.assertEqual(self.reset().returncode, 0)  # fresh/repeated installation

    def test_preserves_saved_runs_custom_databases_and_unrelated_files(self):
        names = ['another-tool', 'in_defense_of_history.sqlite',
                 'liberty-line-simulator-experiment.sqlite',
                 'liberty-line-simulator-1.0.1.sqlite.backup']
        names.extend('liberty-line-simulator-1.0.1-run-20260927-UUID.sqlite' + suffix
                     for suffix in ['', '-wal', '-shm', '-journal'])
        for name in names:
            self.create(name)
        self.create('LibertyLineSimulator')
        self.assertEqual(self.reset().returncode, 0)
        self.assertEqual({p.name for p in self.root.iterdir()}, set(names))
        for name in names:
            self.assertEqual((self.root / name).read_bytes(), b'previous content')

    def test_refuses_directories_before_deleting_anything(self):
        binary = self.create('LibertyLineSimulator')
        (self.root / 'liberty-line-simulator-1.0.1.sqlite').mkdir()
        result = self.reset()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('non-file', result.stderr)
        self.assertTrue(binary.exists())

    def test_refuses_open_database_before_deleting_anything(self):
        binary = self.create('LibertyLineSimulator')
        database = self.create('liberty-line-simulator-1.0.1.sqlite')
        with database.open('rb') as connection:
            self.assertEqual(connection.read(1), b'p')
            result = self.reset()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn('in use', result.stderr)
        self.assertTrue(binary.exists())
        self.assertTrue(database.exists())

    def test_refuses_open_executable(self):
        binary = self.create('LibertyLineSimulator')
        database = self.create('liberty-line-simulator-1.0.1.sqlite')
        with binary.open('rb') as executable:
            self.assertEqual(executable.read(1), b'p')
            result = self.reset()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn('in use', result.stderr)
        self.assertTrue(binary.exists())
        self.assertTrue(database.exists())

    def test_symlink_removal_does_not_remove_target(self):
        retained = self.create('keep.sqlite')
        (self.root / 'liberty-line-simulator-1.0.1.sqlite').symlink_to(retained)
        (self.root / 'LibertyLineSimulator').symlink_to(self.root / 'missing')
        self.assertEqual(self.reset().returncode, 0)
        self.assertEqual(list(self.root.iterdir()), [retained])

    def test_rejects_missing_or_relative_install_directory(self):
        for args in [[], ['relative'], [str(self.root / 'absent')]]:
            result = subprocess.run(['/bin/sh', str(RESET), *args], capture_output=True)
            self.assertNotEqual(result.returncode, 0)


if __name__ == '__main__':
    unittest.main()
