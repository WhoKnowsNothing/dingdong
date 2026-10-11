"""Exercise the real installers and players against disposable user data."""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PS = shutil.which('powershell.exe')
BASH = shutil.which('bash') if os.name != 'nt' else r'C:\Program Files\Git\bin\bash.exe'


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False), encoding='utf-8')


class IntegrationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='dingdong-integration-')
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name)
        self.data = self.work / "shared 设置[1]' directory"
        self.env = {**os.environ, 'DINGDONG_HOME': self.data.as_posix()}
        self.settings = self.work / 'claude-settings.json'
        self.claude = self.work / 'claude' / 'dingdong'
        self.codex = self.work / 'codex' / 'dingdong'

    def ps(self, script, *args, input_text='', check=True):
        if not PS:
            self.skipTest('Windows PowerShell is required')
        def quote(value):
            return "'" + str(value).replace("'", "''") + "'"
        command = '[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false; & ' + quote(script)
        command += ''.join(' ' + (str(a) if re.fullmatch(r'-[A-Za-z]+', str(a)) else quote(a)) for a in args)
        return subprocess.run([PS, '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-Command', command],
                              env=self.env, input=input_text, capture_output=True, text=True,
                              encoding='utf-8', timeout=30, check=check)

    def install(self):
        return self.ps(ROOT / 'scripts/install.ps1', '-TargetDir', self.claude, '-SettingsPath', self.settings)

    def package(self):
        self.ps(ROOT / 'scripts/build-codex.ps1', '-OutputDir', self.codex)

    def inspect(self, root, event='Stop'):
        return json.loads(self.ps(root / 'play-sound.ps1', '-Event', event, '-DryRun').stdout)

    def test_shared_changes_reach_both_clients_and_survive_reinstall(self):
        self.install()
        self.package()
        self.assertEqual(self.inspect(self.claude), self.inspect(self.codex))
        custom = {'version': 2, 'volume': 17, 'events': {'Stop': {'type': 'none'}}}
        write_json(self.data / 'config.json', custom)
        (self.data / 'sounds/custom.wav').write_bytes(b'keep my imported sound')
        self.install()
        self.package()
        for root in (self.claude, self.codex):
            self.assertEqual(self.inspect(root)['type'], 'none')
            self.assertEqual(Path(self.inspect(root)['config']), self.data / 'config.json')
        self.assertEqual(json.loads((self.data / 'config.json').read_text(encoding='utf-8')), custom)
        self.assertEqual((self.data / 'sounds/custom.wav').read_bytes(), b'keep my imported sound')

    def test_migrate_legacy_config_and_custom_sound_without_hook_rewrite(self):
        write_json(self.claude / 'config.json', {'Stop': 'sounds/custom.wav'})
        (self.claude / 'sounds').mkdir()
        (self.claude / 'sounds/custom.wav').write_bytes(b'legacy sound')
        self.install()
        before = (self.data / 'config.json').read_bytes()
        result = self.inspect(self.claude)
        self.assertEqual(Path(result['file']), self.data / 'sounds/custom.wav')
        self.assertEqual((self.data / 'sounds/custom.wav').read_bytes(), b'legacy sound')
        self.assertEqual((self.data / 'config.json').read_bytes(), before)

    def test_install_and_uninstall_preserve_other_handlers_in_same_group(self):
        other = {'type': 'command', 'command': 'echo retain-me', 'timeout': 12}
        old = {'type': 'command', 'command': 'bash /old/dingdong/play-sound.sh Stop'}
        original = {'model': 'unchanged', 'permissions': {'allow': ['Read']},
                    'hooks': {'Stop': [{'matcher': '*', 'hooks': [other, old]}],
                              'SessionStart': [{'hooks': [other]}]}}
        write_json(self.settings, original)
        self.install()
        self.install()
        installed = json.loads(self.settings.read_text(encoding='utf-8'))
        self.assertEqual(len(installed['hooks']['Stop']), 2)
        self.assertEqual(installed['permissions'], original['permissions'])
        self.ps(ROOT / 'scripts/uninstall.ps1', '-SettingsPath', self.settings)
        expected = {**original, 'hooks': {'Stop': [{'matcher': '*', 'hooks': [other]}],
                                        'SessionStart': [{'hooks': [other]}]}}
        self.assertEqual(json.loads(self.settings.read_text(encoding='utf-8')), expected)
        self.assertTrue((self.data / 'config.json').is_file())
        self.assertTrue(list(self.work.glob('claude-settings.json.dingdong-backup-*')))

    def test_invalid_settings_are_never_replaced(self):
        self.settings.write_bytes(b'{ broken JSON')
        result = self.ps(ROOT / 'scripts/install.ps1', '-TargetDir', self.claude,
                         '-SettingsPath', self.settings, check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.settings.read_bytes(), b'{ broken JSON')

    def test_codex_returns_neutral_json_for_silent_missing_and_invalid_config(self):
        self.package()
        cases = [{'version': 2, 'events': {'Stop': {'type': 'none'}}},
                 {'version': 2, 'events': {'Stop': {'type': 'wav', 'file': 'sounds/missing.wav'}}},
                 {'version': 2, 'events': {}}]
        for config in cases:
            write_json(self.data / 'config.json', config)
            result = self.ps(self.codex / 'scripts/on-event.ps1', '-Event', 'Stop',
                             input_text='{"last_assistant_message":"do not retain this payload"}')
            self.assertEqual(result.stdout.strip(), '{}')
            self.assertEqual(result.returncode, 0)
        (self.data / 'config.json').write_text('{ broken', encoding='utf-8')
        result = self.ps(self.codex / 'scripts/on-event.ps1', '-Event', 'Stop', input_text='private payload')
        self.assertEqual(result.stdout.strip(), '{}')
        self.assertNotIn('private payload', result.stdout + result.stderr)
        self.assertEqual([p.name for p in self.data.iterdir()], ['config.json'])

    def test_package_uses_repo_players_and_only_supported_codex_hooks(self):
        self.package()
        for file in ('play-sound.ps1', 'play-sound.sh', 'config-ui.ps1', 'scripts/data-paths.ps1', 'scripts/on-event.ps1'):
            self.assertEqual((self.codex / file).read_bytes(), (ROOT / file).read_bytes())
        hooks = json.loads((self.codex / 'hooks/hooks.json').read_text(encoding='utf-8'))['hooks']
        self.assertEqual(set(hooks), {'Stop', 'PermissionRequest', 'PreToolUse', 'SubagentStop'})
        pattern = hooks['PreToolUse'][0]['matcher']
        for name in ('request_user_input', 'request_user_input_async', 'functions.request_user_input_async', 'send_user_message_async'):
            self.assertRegex(name, pattern)
        for name in ('exec_command', 'send_message_to_thread', 'request_user_input_example'):
            self.assertNotRegex(name, pattern)

    def test_codex_update_uses_native_cli_and_preserves_shared_data(self):
        if not shutil.which('codex'):
            self.skipTest('Codex CLI is required')
        self.package()
        self.env['CODEX_HOME'] = str(self.work / 'codex-home')
        (self.work / 'codex-home').mkdir()
        self.env['DINGDONG_TEST_MARKETPLACE_ROOT'] = str(self.work)
        write_json(self.work / '.agents/plugins/marketplace.json', {
            'name': 'dingdong-test', 'plugins': [{
                'name': 'dingdong', 'source': {'source': 'local', 'path': './codex/dingdong'},
                'policy': {'installation': 'AVAILABLE', 'authentication': 'ON_INSTALL'},
                'category': 'Productivity'}]})
        setup = self.work / 'register-marketplace.ps1'
        setup.write_text(
            '& codex plugin marketplace add $env:DINGDONG_TEST_MARKETPLACE_ROOT --json\n'
            "if ($LASTEXITCODE -ne 0) { throw 'Test marketplace registration failed' }\n",
            encoding='utf-8')
        self.ps(setup)
        custom = {'version': 2, 'events': {'Stop': {'type': 'none'}}}
        write_json(self.data / 'config.json', custom)
        (self.data / 'sounds').mkdir()
        (self.data / 'sounds/custom.wav').write_bytes(b'keep my sound')
        versions = []
        for _ in range(2):
            self.ps(ROOT / 'scripts/update-codex.ps1', '-Marketplace', 'dingdong-test')
            manifest = json.loads((self.codex / '.codex-plugin/plugin.json').read_text(encoding='utf-8'))
            self.assertRegex(manifest['version'], r'^\d+\.\d+\.\d+\+codex\.\d+$')
            versions.append(manifest['version'])
        self.assertNotEqual(*versions)
        self.assertEqual(json.loads((self.data / 'config.json').read_text(encoding='utf-8')), custom)
        self.assertEqual((self.data / 'sounds/custom.wav').read_bytes(), b'keep my sound')
        installed = self.work / 'codex-home/plugins/cache/dingdong-test/dingdong' / versions[-1]
        self.assertEqual((installed / 'scripts/on-event.ps1').read_bytes(), (ROOT / 'scripts/on-event.ps1').read_bytes())
        self.assertTrue(list((self.work / 'codex-home/backups').glob('dingdong-update-*/plugin')))

    def stub_codex_audio(self):
        self.package()
        self.data.mkdir(parents=True)
        self.played = self.work / 'played-events.txt'
        self.env['DINGDONG_TEST_RESULT'] = str(self.played)
        self.env['DINGDONG_TEST_MUTEX'] = 'Local\\' + self.work.name
        (self.codex / 'play-sound.ps1').write_text(
            "param([string]$Event)\n"
            "$mutex = New-Object Threading.Mutex($false, $env:DINGDONG_TEST_MUTEX)\n"
            "[void]$mutex.WaitOne()\n"
            "try { [IO.File]::AppendAllText($env:DINGDONG_TEST_RESULT, $Event + [Environment]::NewLine) }\n"
            "finally { $mutex.ReleaseMutex(); $mutex.Dispose() }\n",
            encoding='utf-8')

    def invoke_codex_event(self, payload, event='Stop'):
        result = self.ps(self.codex / 'scripts/on-event.ps1', '-Event', event,
                         input_text=json.dumps(payload))
        self.assertEqual(result.stdout.strip(), '{}')
        self.assertEqual(result.stderr, '')

    def test_codex_completion_replays_do_not_repeat_audio_or_mute_other_turns(self):
        self.stub_codex_audio()
        payload = {'session_id': 'session-a', 'turn_id': 'turn-1', 'hook_event_name': 'Stop',
                   'last_assistant_message': 'PRIVATE MESSAGE MUST NOT BE SAVED'}
        self.invoke_codex_event(payload)
        self.invoke_codex_event({**payload, 'last_assistant_message': 'different final text'})
        self.invoke_codex_event({**payload, 'turn_id': 'turn-2'})
        self.invoke_codex_event({**payload, 'session_id': 'session-b'})
        # A late delivery still belongs to the original turn, even after other completions.
        self.invoke_codex_event(payload)
        self.assertEqual(self.played.read_text().splitlines(), ['Stop'] * 3)
        for path in self.data.rglob('*'):
            self.assertNotIn('session-a', path.name)
            self.assertNotIn('turn-1', path.name)
            if path.is_file():
                self.assertEqual(path.read_bytes(), b'')

    def test_codex_concurrent_completion_callbacks_play_once(self):
        self.stub_codex_audio()
        payload = {'session_id': 'session-a', 'turn_id': 'turn-1', 'hook_event_name': 'Stop'}
        with ThreadPoolExecutor(max_workers=6) as pool:
            list(pool.map(lambda _: self.invoke_codex_event(payload), range(6)))
        self.assertEqual(self.played.read_text().splitlines(), ['Stop'])

    def test_codex_utf8_completions_deduplicate_under_legacy_console_encoding(self):
        self.stub_codex_audio()
        launcher = self.work / 'legacy-console.ps1'
        launcher.write_text(
            "[Console]::InputEncoding = [Text.Encoding]::GetEncoding(936)\n"
            "& (Join-Path $env:DINGDONG_TEST_PLUGIN 'scripts/on-event.ps1') -Event Stop\n",
            encoding='utf-8')
        self.env['DINGDONG_TEST_PLUGIN'] = str(self.codex)
        payload = {'session_id': 'session-a', 'turn_id': 'turn-1',
                   'transcript_path': r'C:\sessions\conversation.jsonl',
                   'last_assistant_message': '修复好'}
        for _ in range(2):
            result = self.ps(launcher, input_text=json.dumps(payload, ensure_ascii=False))
            self.assertEqual(result.stdout.strip(), '{}')
            self.assertEqual(result.stderr, '')
        self.assertEqual(self.played.read_text().splitlines(), ['Stop'])

    def test_codex_background_completions_do_not_play_task_done_sound(self):
        self.stub_codex_audio()
        foreground = {'session_id': 'session-a', 'turn_id': 'turn-1',
                      'transcript_path': r'C:\sessions\conversation.jsonl'}
        self.invoke_codex_event(foreground)
        for path in (None, ''):
            self.invoke_codex_event({'session_id': 'internal-session', 'turn_id': 'internal-turn',
                                     'transcript_path': path})
        # A new user task may finish immediately and must still notify.
        self.invoke_codex_event({**foreground, 'turn_id': 'turn-2'})
        self.assertEqual(self.played.read_text().splitlines(), ['Stop', 'Stop'])
        self.assertEqual(len(list((self.data / 'state/codex-stop').glob('*.done'))), 2)

    def test_codex_other_events_and_unidentified_completions_keep_playing(self):
        self.stub_codex_audio()
        payload = {'session_id': 'session-a', 'turn_id': 'turn-1'}
        for event in ('Elicitation', 'PermissionRequest', 'Notification'):
            for _ in range(2):
                self.invoke_codex_event(payload, event)
        for payload in ({}, {'session_id': 'session-a'}, {'session_id': ['invalid'], 'turn_id': 'turn-1'}):
            for _ in range(2):
                self.invoke_codex_event(payload)
        self.assertEqual(self.played.read_text().splitlines(),
                         ['Elicitation'] * 2 + ['PermissionRequest'] * 2 + ['Notification'] * 2 + ['Stop'] * 6)

    def test_codex_completion_state_failure_does_not_mute_audio(self):
        self.stub_codex_audio()
        # Simulate an unwritable state location without changing real user permissions.
        (self.data / 'state').write_text('not a directory', encoding='utf-8')
        payload = {'session_id': 'session-a', 'turn_id': 'turn-1'}
        result = self.ps(self.codex / 'scripts/on-event.ps1', '-Event', 'Stop',
                         input_text=json.dumps(payload))
        self.assertEqual(result.stdout.strip(), '{}')
        self.assertEqual(self.played.read_text().splitlines(), ['Stop'])

    def test_unix_settings_merge_preserves_other_handlers_and_quotes_paths(self):
        other = {'type': 'command', 'command': 'echo keep'}
        write_json(self.settings, {'custom': [1, 2], 'hooks': {'Stop': [{'hooks': [other]}]}})
        args = [sys.executable, str(ROOT / 'scripts/claude-settings.py')]
        for _ in range(2):
            subprocess.run(args + ['install', str(self.settings), str(ROOT / 'hooks.unix.json'),
                                  str(self.work / "a quoted' path/dingdong")], check=True, capture_output=True)
        installed = json.loads(self.settings.read_text(encoding='utf-8'))
        self.assertEqual(len(installed['hooks']['Stop']), 2)
        subprocess.run(args + ['uninstall', str(self.settings)], check=True, capture_output=True)
        self.assertEqual(json.loads(self.settings.read_text(encoding='utf-8')),
                         {'custom': [1, 2], 'hooks': {'Stop': [{'hooks': [other]}]}})

    def test_unix_player_reads_shared_unicode_path_using_audio_stub(self):
        if not BASH or not Path(BASH).is_file():
            self.skipTest('Bash is required')
        write_json(self.data / 'config.json', {'version': 2, 'events': {'Stop': {'type': 'wav', 'file': 'sounds/custom.wav'}}})
        (self.data / 'sounds').mkdir()
        (self.data / 'sounds/custom.wav').write_bytes(b'stub audio')
        stub_dir = self.work / 'bin'
        stub_dir.mkdir()
        stub = stub_dir / 'paplay'
        stub.write_text('#!/usr/bin/env bash\nprintf "%s" "$1" > "$DINGDONG_TEST_RESULT"\n', encoding='utf-8', newline='\n')
        stub.chmod(0o755)
        result_file = self.work / 'played-path.txt'
        bin_path = stub_dir.as_posix()
        if os.name == 'nt':
            bin_path = '/' + bin_path[0].lower() + bin_path[2:]
        env = {**self.env, 'DINGDONG_TEST_BIN': bin_path,
               'DINGDONG_TEST_RESULT': result_file.as_posix(), 'DINGDONG_TEST_PLAYER': (ROOT / 'play-sound.sh').as_posix()}
        result = subprocess.run([BASH, '-c', 'export PATH="$DINGDONG_TEST_BIN:$PATH"; exec bash "$DINGDONG_TEST_PLAYER" Stop'],
                                env=env, capture_output=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stderr.decode('utf-8', errors='replace'))
        self.assertEqual(Path(result_file.read_text(encoding='utf-8')), self.data / 'sounds/custom.wav')


if __name__ == '__main__':
    unittest.main(verbosity=2)
