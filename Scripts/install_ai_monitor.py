#!/usr/bin/env python3
"""Install the tested app at its stable path; never rename a live widget host.

Run with the path to a freshly packaged AI Monitor.app. No account files are changed.
Legacy Studio widgets must be removed/re-added once after this extension migration.
"""
import argparse
import datetime
import os
import pathlib
import plistlib
import signal
import subprocess
import time
import uuid

from verify_ai_monitor_bundle import validate

CANONICAL = pathlib.Path('/Applications/AI Monitor.app')
LEGACY = pathlib.Path('/Applications/CodexBar Studio.app')
LSREGISTER = '/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'


def install(source):
    source = source.resolve()
    if source == CANONICAL.resolve():
        raise SystemExit('Choose a packaged source outside /Applications/AI Monitor.app')
    validate(source)
    for app in (CANONICAL, LEGACY):
        if app.exists():
            info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
            if info.get('CFBundleIdentifier') != 'com.steipete.codexbar.debug':
                raise SystemExit(f'Refusing to replace an unrelated application: {app}')
    target_executables = {str(app / 'Contents/MacOS/CodexBar') for app in (CANONICAL, LEGACY)}
    stopped = []
    for row in subprocess.check_output(['ps', '-axo', 'pid=,comm='], text=True).splitlines():
        pid, command = row.strip().split(None, 1)
        if command in target_executables:
            os.kill(int(pid), signal.SIGTERM)
            stopped.append(int(pid))
    for _ in range(50):
        alive = []
        for pid in stopped:
            try:
                os.kill(pid, 0)
                alive.append(pid)
            except ProcessLookupError:
                pass
        if not alive:
            break
        time.sleep(0.1)
    else:
        raise SystemExit('Application is still running; quit it before installing')
    backup = pathlib.Path.home() / 'Library/Application Support/AI Monitor/Installation Backups'
    backup = backup / datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    backup.mkdir(parents=True)
    staging_root = CANONICAL.parent / ('.ai-monitor-staging-' + uuid.uuid4().hex)
    staging_root.mkdir()
    staged = staging_root / CANONICAL.name
    subprocess.run(['ditto', str(source), str(staged)], check=True)
    validate(staged)
    try:
        for app in (CANONICAL, LEGACY):
            if not app.exists():
                continue
            old_extension = app / 'Contents/PlugIns/CodexBarWidget.appex'
            old_info = plistlib.loads((old_extension / 'Contents/Info.plist').read_bytes())
            if app != CANONICAL or old_info.get('CFBundleIdentifier') != 'com.steipete.codexbar.debug.aimonitor.widget':
                subprocess.run(['pluginkit', '-r', str(old_extension)], check=False)
                subprocess.run([LSREGISTER, '-u', str(app)], check=False)
            app.rename(backup / (app.stem + '.backup'))
        staged.rename(CANONICAL)
        staging_root.rmdir()
    except Exception:
        if not CANONICAL.exists() and (backup / 'AI Monitor.backup').exists():
            (backup / 'AI Monitor.backup').rename(CANONICAL)
        raise
    subprocess.run([LSREGISTER, '-f', str(CANONICAL)], check=True)
    subprocess.run(['pluginkit', '-a', str(CANONICAL / 'Contents/PlugIns/CodexBarWidget.appex')], check=True)
    validate(CANONICAL)
    print('Installed at /Applications/AI Monitor.app. Account configuration is unchanged.')
    print('Replace legacy Studio/beta.1 desktop widgets once from the AI Monitor widget gallery.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('application', type=pathlib.Path)
    install(parser.parse_args().application)
