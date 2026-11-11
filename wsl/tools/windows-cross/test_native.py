import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('native', Path(__file__).with_name('native.py'))
native = importlib.util.module_from_spec(spec)
spec.loader.exec_module(native)


class NativeTests(unittest.TestCase):
    def test_hash_mismatch_does_not_publish(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            artifact = {'url': 'https://example.invalid/sdk.msi', 'sha256': '0' * 64}
            def fetch(arguments, **kwargs):
                Path(arguments[-1]).write_bytes(b'corrupted download')
            with patch.object(native, 'CACHE', root), patch.object(native, 'ARTIFACTS', {'test': artifact}), patch.object(native.subprocess, 'run', side_effect=fetch):
                with self.assertRaisesRegex(ValueError, 'SHA-256'):
                    native.download('test')
            self.assertEqual(list(root.iterdir()), [])

    def test_verified_download_is_reused(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / 'sdk.msi'
            path.write_bytes(b'verified')
            with patch.object(native, 'CACHE', path.parent), patch.object(native, 'ARTIFACTS', {'test': {'url': 'https://example.invalid/sdk.msi', 'sha256': native.digest(path)}}), patch.object(native.subprocess, 'run') as fetch:
                self.assertEqual(native.download('test'), path)
                fetch.assert_not_called()

    def test_existing_sdk_does_not_download(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            with patch.dict(native.DESTINATIONS, {'sdk': root}), patch.object(native, 'validate') as validate, patch.object(native, 'download') as fetch, contextlib.redirect_stdout(io.StringIO()):
                native.prepare('sdk')
                validate.assert_called_once_with('sdk', root)
                fetch.assert_not_called()

    def test_corrupt_cache_is_preserved(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / 'sdk.msi'
            path.write_bytes(b'existing')
            with patch.object(native, 'CACHE', path.parent), patch.object(native, 'ARTIFACTS', {'test': {'url': 'https://example.invalid/sdk.msi', 'sha256': '0' * 64}}):
                with self.assertRaises(ValueError):
                    native.download('test')
            self.assertEqual(path.read_bytes(), b'existing')

    def test_incomplete_sdk_is_preserved(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'existing').write_text('preserve')
            with patch.dict(native.DESTINATIONS, {'sdk': root}):
                with self.assertRaisesRegex(ValueError, 'incompleta'):
                    native.prepare('sdk')
            self.assertEqual((root / 'existing').read_text(), 'preserve')

    def test_real_elf_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'nao e Windows AMD64'):
            native.architecture(Path('/usr/bin/true'))

    def test_reject_elf_and_wrong_machine(self):
        for headers in ['Format: ELF64-x86-64\nMachine: EM_X86_64', 'Format: COFF-i386\nMachine: IMAGE_FILE_MACHINE_I386', 'Format: COFF-x86-64\nMachine: IMAGE_FILE_MACHINE_AMD64\nMachine: IMAGE_FILE_MACHINE_I386']:
            with patch.object(native.subprocess, 'check_output', return_value=headers):
                with self.assertRaises(ValueError):
                    native.architecture(Path('test.lib'))

    def test_inventory_detects_corruption(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            asset = root / 'header.h'
            asset.write_text('original')
            (root / 'inventory.json').write_text(json.dumps({'header.h': native.digest(asset)}))
            asset.write_text('corrupt')
            with self.assertRaisesRegex(ValueError, 'SHA-256'):
                native.validate('sdk', root)

    def test_pkg_config_rejects_host_paths(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'lib/pkgconfig').mkdir(parents=True)
            (root / 'lib/pkgconfig/test.pc').write_text('Name: test\nDescription: test\nVersion: 1\nCflags: -I/usr/include\nLibs: -L/usr/lib -lm\n')
            result = subprocess.run([str(Path(__file__).with_name('pkg-config.py')), '--cflags', '--libs', 'test'], env={**os.environ, 'WINDOWS_CROSS_SDK': str(root), 'PKG_CONFIG_PATH': '/usr/lib/pkgconfig'}, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('fora do SDK', result.stderr)


if __name__ == '__main__':
    unittest.main()
