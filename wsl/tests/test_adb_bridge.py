#!/usr/bin/python
import contextlib
import importlib.machinery
import importlib.util
import io
import json
import os
import socket
import subprocess
import tempfile
import threading
import unittest
from pathlib import Path
from unittest import mock

TOOLS = Path(__file__).resolve().parents[1] / "tools"


def load(name, path):
    loader = importlib.machinery.SourceFileLoader(name, str(path))
    spec = importlib.util.spec_from_loader(name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


bridge = load("adb_bridge", TOOLS / "adb-bridge")
settings = load("adb_settings", TOOLS / "android-studio-adb-settings.py")


class BridgeTests(unittest.TestCase):
    def test_healthy_server_never_invokes_windows(self):
        with mock.patch.object(bridge, "probe"), mock.patch.object(bridge.subprocess, "run") as run:
            bridge.ensure()
            run.assert_not_called()

    def test_stopped_server_invokes_bounded_windows_helper_then_probes(self):
        results = [subprocess.CompletedProcess([], 0, stdout="C:\\helper.ps1\n"),
                   subprocess.CompletedProcess([], 0, stdout=b"started", stderr=b"")]
        with mock.patch.object(bridge, "probe", side_effect=[ConnectionRefusedError(), None]), \
             mock.patch.object(bridge.subprocess, "run", side_effect=results) as run, \
             contextlib.redirect_stderr(io.StringIO()):
            bridge.ensure()
        self.assertEqual(run.call_count, 2)
        invocation = run.call_args
        self.assertEqual(invocation.kwargs["timeout"], 16)
        self.assertEqual(invocation.kwargs["stdin"], subprocess.DEVNULL)
        self.assertNotIn("-L", invocation.args[0])

    def test_windows_failure_is_reported(self):
        with mock.patch.object(bridge, "probe", side_effect=ConnectionRefusedError()), \
             mock.patch.object(bridge.subprocess, "run", side_effect=[
                 subprocess.CompletedProcess([], 0, stdout="C:\\helper.ps1"),
                 subprocess.CompletedProcess([], 1, stdout=b"", stderr=b"port busy")]), \
             contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaisesRegex(OSError, "Windows nao"):
                bridge.ensure()

    def test_bridge_failure_is_distinct_from_windows_failure(self):
        with mock.patch.object(bridge, "probe", side_effect=TimeoutError()), \
             mock.patch.object(bridge.subprocess, "run", side_effect=[
                 subprocess.CompletedProcess([], 0, stdout="C:\\helper.ps1"),
                 subprocess.CompletedProcess([], 0, stdout=b"healthy", stderr=b"")]), \
             mock.patch.object(bridge.time, "monotonic", side_effect=[0, 5]), \
             contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaisesRegex(OSError, "ponte WSL falhou"):
                bridge.ensure()

    def test_status_does_not_start_and_distinguishes_device_states(self):
        for devices, message in [("", "Nenhum dispositivo"), ("serial\tunauthorized", "Autorizacao pendente"),
                                 ("serial             unauthorized usb:1", "Autorizacao pendente"),
                                 ("serial             offline", "Dispositivo offline"),
                                 ("serial\toffline", "Dispositivo offline"), ("serial\tdevice", "serial\tdevice")]:
            with self.subTest(devices=devices), mock.patch.object(bridge.sys, "argv", ["adb-bridge", "status"]), \
                 mock.patch.object(bridge, "probe"), mock.patch.object(bridge, "query", return_value=devices), \
                 mock.patch.object(bridge, "ensure") as ensure, contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(bridge.main(), 0)
                self.assertIn(message, output.getvalue())
                ensure.assert_not_called()

    def test_protocol_reads_fragmented_reply_and_rejects_non_adb(self):
        stream = mock.MagicMock()
        stream.__enter__.return_value = stream
        stream.recv.side_effect = [b"OK", b"AY", b"00", b"04", b"00", b"29"]
        with mock.patch.object(bridge.socket, "create_connection", return_value=stream):
            self.assertEqual(bridge.query("host:version"), "0029")
        stream.sendall.assert_called_once_with(b"000chost:version")
        stream.recv.side_effect = [b"HTTP"]
        with mock.patch.object(bridge.socket, "create_connection", return_value=stream):
            with self.assertRaisesRegex(OSError, "fora do protocolo"):
                bridge.query("host:version")


class SettingsTests(unittest.TestCase):
    def test_detects_native_launcher_and_jvm(self):
        self.assertTrue(settings.is_studio_process([b'/usr/bin/android-studio'], 'android-studio', None))
        self.assertTrue(settings.is_studio_process([b'custom-name'], 'MainThread', Path('/opt/android-studio/bin/studio')))
        self.assertTrue(settings.is_studio_process([b'java', b'-Didea.paths.selector=AndroidStudio2026.1.4'], 'java', None))
        self.assertFalse(settings.is_studio_process([b'java', b'other-project'], 'java', None))

    def test_preserve_properties_backup_idempotence_and_targeted_undo(self):
        with tempfile.TemporaryDirectory() as directory, mock.patch.object(settings, "assert_closed"):
            path = Path(directory) / "other.xml"
            original = '<application><component name="Unrelated"><option name="x" value="1" /></component><component name="PropertyService"><![CDATA[{"keyToString":{"keep":"yes"},"keyToStringList":{"list":["a"]}}]]></component></application>'
            path.write_text(original)
            self.assertTrue(settings.update(path, settings.KEYS))
            after = path.read_text()
            self.assertIn('<option name="x" value="1" />', after)
            self.assertEqual(settings.properties(after)["keyToString"]["keep"], "yes")
            self.assertEqual(settings.properties(after)["keyToStringList"], {"list": ["a"]})
            self.assertEqual(path.with_name("other.xml.adb-bridge.bak").read_text(), original)
            self.assertFalse(settings.update(path, settings.KEYS))
            self.assertEqual(path.read_text(), after)
            # A later IDE preference must survive undo of the two ADB keys.
            path.write_text(after.replace('"keep": "yes"', '"keep": "changed later"'))
            self.assertTrue(settings.update(path, settings.properties(original)["keyToString"]))
            current = settings.properties(path.read_text())["keyToString"]
            self.assertEqual(current, {"keep": "changed later"})

    def test_open_ide_and_invalid_json_are_not_modified(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "other.xml"
            path.write_text('<application><component name="PropertyService">invalid</component></application>')
            original = path.read_bytes()
            with mock.patch.object(settings, "assert_closed", side_effect=RuntimeError("IDE open")):
                with self.assertRaisesRegex(RuntimeError, "IDE open"):
                    settings.update(path, settings.KEYS)
            with mock.patch.object(settings, "assert_closed"):
                with self.assertRaises(ValueError):
                    settings.update(path, settings.KEYS)
            self.assertEqual(path.read_bytes(), original)

    def test_empty_config_and_missing_property_service(self):
        for original in ["", '<application>\n<component name="Other" />\n</application>']:
            rendered = settings.render(original, settings.KEYS)
            self.assertEqual(settings.properties(rendered)["keyToString"], settings.KEYS)


class WrapperTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.calls = self.root / "calls"
        self.native = self.root / "adb-native"
        self.native.write_text('#!/bin/sh\nprintf "native:%s\\n" "$*" >> "$TEST_CALLS"\n')
        self.native.chmod(0o755)
        helper = self.root / ".local/bin/adb-bridge"
        helper.parent.mkdir(parents=True)
        helper.write_text('#!/bin/sh\nprintf "ensure\\n" >> "$TEST_CALLS"\nexit "${TEST_ENSURE_EXIT:-0}"\n')
        helper.chmod(0o755)
        self.wrapper = self.root / "adb"
        self.wrapper.write_text((TOOLS / "adb-client").read_text().replace('/usr/bin/adb', str(self.native)))
        self.env = dict(os.environ, HOME=str(self.root), TEST_CALLS=str(self.calls))

    def run_adb(self, *args):
        if self.calls.exists():
            self.calls.unlink()
        result = subprocess.run(["bash", str(self.wrapper), *args], env=self.env, capture_output=True, text=True, timeout=3)
        return result, self.calls.read_text() if self.calls.exists() else ""

    def test_help_version_kill_and_keygen_never_ensure(self):
        for args in [[], ["version"], ["help"], ["--help"], ["kill-server"], ["keygen", "key"]]:
            with self.subTest(args=args):
                result, calls = self.run_adb(*args)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertNotIn("ensure", calls)

    def test_commands_ensure_and_keep_arguments(self):
        for args in [["devices", "-l"], ["-s", "serial space", "shell", "echo", "hello world"], ["-H", "127.0.0.1", "-P", "5037", "devices"]]:
            result, calls = self.run_adb(*args)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue(calls.startswith("ensure\nnative:-H 127.0.0.1 -P 5037 "))
        result, calls = self.run_adb("start-server")
        self.assertEqual((result.returncode, calls), (0, "ensure\n"))

    def test_unsafe_server_options_and_helper_failure(self):
        for args in [["-a", "devices"], ["-H", "elsewhere", "devices"], ["-P", "5038", "devices"], ["-L", "tcp:5037", "start-server"], ["server"], ["nodaemon"], ["-s"]]:
            result, calls = self.run_adb(*args)
            self.assertEqual(result.returncode, 2, (args, result.stderr))
            self.assertEqual(calls, "")
        self.env["TEST_ENSURE_EXIT"] = "1"
        result, calls = self.run_adb("devices")
        self.assertEqual((result.returncode, calls), (1, "ensure\n"))


if __name__ == "__main__":
    unittest.main()
