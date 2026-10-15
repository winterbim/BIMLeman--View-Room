"""Regression checks against the pinned, real upstream source (not a mock tree)."""
import hashlib
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import unittest
from PIL import Image

HERE = Path(__file__).resolve().parent
UPSTREAM = Path(os.environ['VEYON_SOURCE'])


class NativeBrandingTests(unittest.TestCase):
    def test_native_resources_and_legal_preservation(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            archive = subprocess.check_output(['git', '-C', str(UPSTREAM), 'archive', 'HEAD'])
            import io
            with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
                tar.extractall(root, filter='data')
            vnc = root / '3rdparty/ultravnc/winvnc/winvnc/vnckeymap.cpp'
            vnc.parent.mkdir(parents=True, exist_ok=True)
            vnc.write_bytes(subprocess.check_output(['git', '-C', str(UPSTREAM/'3rdparty/ultravnc'),
                'show', 'HEAD:winvnc/winvnc/vnckeymap.cpp']))
            preserved = ['COPYING', 'core/src/VeyonCore.cpp', 'master/src/VeyonMaster.cpp',
                         'core/src/AuthenticationCredentials.cpp']
            before = {p: (root / p).read_bytes() for p in preserved}
            result = subprocess.run([sys.executable, str(HERE / 'prepare_native.py'),
                '--source', str(root), '--logo', str(HERE.parent / 'assets/brand/BIMLeman-View-Room-logo.png'),
                '--report', str(root / 'report.json')], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            ui = (root / 'master/src/MainWindow.ui').read_text(encoding='utf-8')
            self.assertIn('BIMLéman View Room', ui)
            self.assertIn(':/master/bimleman-icon.png', ui)
            self.assertIn('--bimleman-self-test', (root / 'master/src/main.cpp').read_text(encoding='utf-8'))
            self.assertEqual(before, {p: (root / p).read_bytes() for p in preserved})
            with Image.open(root / 'master/data/veyon-master.ico') as ico:
                self.assertIn((256, 256), ico.info['sizes'])
            with Image.open(root / 'master/resources/splash.png') as splash:
                self.assertEqual(splash.size, (720, 400))

    def test_unknown_sources_refused_without_mutation(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'master/src').mkdir(parents=True)
            ui = root / 'master/src/MainWindow.ui'
            ui.write_text('Veyon Master')
            before = ui.read_bytes()
            result = subprocess.run([sys.executable, str(HERE / 'prepare_native.py'),
                '--source', str(root), '--logo', str(HERE.parent / 'assets/brand/BIMLeman-View-Room-logo.png'),
                '--report', str(root / 'report.json')], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(before, ui.read_bytes())


if __name__ == '__main__':
    unittest.main()
