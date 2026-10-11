"""Merge only DingDong handlers; preserve other Claude settings and hooks."""
import copy
import datetime
import json
import re
import shlex
import shutil
import sys
from pathlib import Path


def update(mode, settings_path, hooks_path=None, plugin_root=None):
    path = Path(settings_path)
    if mode == 'uninstall' and not path.exists():
        return
    settings = json.loads(path.read_text(encoding='utf-8-sig')) if path.exists() else {}
    if not isinstance(settings, dict) or not isinstance(settings.get('hooks', {}), dict):
        raise ValueError('Claude settings and hooks must be JSON objects.')
    hooks = settings.get('hooks', {})
    for event, groups in list(hooks.items()):
        retained = []
        for group in groups or []:
            remaining = [h for h in group['hooks'] if not re.search(
                r'dingdong[\\/].*play-sound\.(ps1|sh)', h.get('command', ''), re.I)]
            if remaining:
                retained.append({**group, 'hooks': remaining})
        if retained:
            hooks[event] = retained
        else:
            del hooks[event]
    if mode == 'install':
        incoming = json.loads(Path(hooks_path).read_text(encoding='utf-8-sig'))['hooks']
        for event, groups in incoming.items():
            for group in groups:
                for handler in group['hooks']:
                    sound_event = shlex.split(handler['command'])[-1]
                    handler['command'] = 'bash ' + shlex.quote(str(Path(plugin_root).resolve() / 'play-sound.sh')) + ' ' + shlex.quote(sound_event)
            hooks.setdefault(event, []).extend(copy.deepcopy(groups))
    if hooks:
        settings['hooks'] = hooks
    else:
        settings.pop('hooks', None)
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
        shutil.copy2(path, str(path) + '.dingdong-backup-' + stamp)
    path.write_text(json.dumps(settings, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print('Claude Code hooks updated.')


if __name__ == '__main__':
    update(*sys.argv[1:])
