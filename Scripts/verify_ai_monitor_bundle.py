#!/usr/bin/env python3
"""Fail packaging when a Studio extension or mismatched sharing entitlement leaks in."""
import pathlib
import plistlib
import subprocess
import sys


def read_plist(path):
    return plistlib.loads(path.read_bytes())


def entitlements(bundle):
    result = subprocess.run(
        ['codesign', '-d', '--entitlements', ':-', str(bundle)],
        check=True, capture_output=True,
    )
    return plistlib.loads(result.stdout)


def validate(app):
    extension = app / 'Contents/PlugIns/CodexBarWidget.appex'
    host_info = read_plist(app / 'Contents/Info.plist')
    widget_info = read_plist(extension / 'Contents/Info.plist')
    assert app.name == 'AI Monitor.app', 'Installable application name must remain stable'
    assert host_info['CFBundleDisplayName'] == 'AI Monitor'
    assert widget_info['CFBundleIdentifier'] == 'com.steipete.codexbar.debug.aimonitor.widget', (
        'Legacy Studio widget identity must not be reused after the application rename'
    )
    assert widget_info['CFBundleIdentifier'].startswith(host_info['CFBundleIdentifier'] + '.')
    assert host_info['CFBundleVersion'] == widget_info['CFBundleVersion']
    assert (extension / 'Contents/MacOS' / widget_info['CFBundleExecutable']).is_file()
    main_groups = entitlements(app).get('com.apple.security.application-groups')
    widget_entitlements = entitlements(extension)
    assert main_groups and main_groups == widget_entitlements.get('com.apple.security.application-groups')
    assert widget_entitlements.get('com.apple.security.app-sandbox') is True
    assert host_info.get('SUEnableAutomaticChecks') is False
    assert host_info.get('SUAutomaticallyUpdate') is False
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
    print('AI Monitor bundle identity, sharing, executable and signature checks passed.')


if __name__ == '__main__':
    validate(pathlib.Path(sys.argv[1]))
