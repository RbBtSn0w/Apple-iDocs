"""Reconcile existing-tag GitHub release assets without rebuilding or overwriting."""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path


def command(arguments: list[str]) -> str:
    return subprocess.check_output(arguments, text=True, timeout=120).strip()


def download(repository: str, asset_id: int) -> bytes:
    return subprocess.check_output(['gh', 'api', f'repos/{repository}/releases/assets/{asset_id}',
                                    '-H', 'Accept: application/octet-stream'], timeout=120)


def verify_tag(repository: str, tag: str, candidate: str) -> None:
    if not re.fullmatch(r'v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)', tag):
        raise ValueError('invalid original stable tag')
    rows = [line.split() for line in command(['git', 'ls-remote', f'https://github.com/{repository}.git',
                                             f'refs/tags/{tag}', f'refs/tags/{tag}^{{}}']).splitlines()]
    values = {row[1]: row[0] for row in rows if len(row) == 2}
    if values.get(f'refs/tags/{tag}^{{}}', values.get(f'refs/tags/{tag}')) != candidate:
        raise ValueError('original tag does not identify sealed candidate')


def verify_release_record(release: dict, tag: str, notes: str, release_id: int) -> None:
    if release.get('tag_name') != tag or release.get('id') != release_id:
        raise ValueError('GitHub release identity differs from original release')
    if release.get('body') != notes:
        raise ValueError('GitHub release notes differ from original notes')
    if release.get('prerelease') is not False:
        raise ValueError('original release unexpectedly prerelease')


def reconcile_assets(repository: str, release: dict, directory: Path, names: list[str], notes: str) -> None:
    verify_release_record(release, release['tag_name'], notes, release['id'])
    assets = release.get('assets', [])
    missing = []
    # Read every existing asset before the first external write.
    for name in names:
        path = directory / name
        if Path(name).name != name or not path.is_file() or path.is_symlink():
            raise ValueError('invalid sealed release asset')
        matching = [asset for asset in assets if asset['name'] == name]
        if len(matching) > 1:
            raise ValueError('ambiguous release asset')
        if matching:
            if hashlib.sha256(download(repository, matching[0]['id'])).digest() != hashlib.sha256(path.read_bytes()).digest():
                raise ValueError('existing release asset differs from sealed bytes')
        else:
            missing.append(name)
    for name in missing:
        path = directory / name
        command(['gh', 'release', 'upload', release['tag_name'], str(path), '--repo', repository])
        fresh = json.loads(command(['gh', 'api', f'repos/{repository}/releases/{release["id"]}']))
        verify_release_record(fresh, release['tag_name'], notes, release['id'])
        match = [asset for asset in fresh['assets'] if asset['name'] == name]
        if len(match) != 1 or download(repository, match[0]['id']) != path.read_bytes():
            raise ValueError('uploaded release asset not confirmed')

def recover(repository: str, directory: Path, plan: dict, names: list[str]) -> None:
    original_notes = plan.get('notes')
    if not isinstance(original_notes, str):
        raise ValueError('original generated release notes are unavailable')
    # Empty notes require an exact empty remote string; null is never equivalent.
    version = plan.get('version') or plan['next']['version']
    tag = f'v{version}'
    verify_tag(repository, tag, plan['candidate'])
    # List response distinguishes absence from authentication/network failures.
    releases = json.loads(command(['gh', 'api', '--paginate', '--slurp', f'repos/{repository}/releases?per_page=100']))
    matching = [release for page in releases for release in page if release['tag_name'] == tag]
    if len(matching) > 1:
        raise ValueError('ambiguous release identity')
    if matching:
        release = matching[0]
    else:
        notes = directory.parent / 'original-release-notes.md'
        notes.write_text(original_notes, encoding='utf-8')
        command(['gh', 'release', 'create', tag, '--repo', repository, '--verify-tag', '--draft', '--latest=false',
                 '--title', tag, '--notes-file', str(notes)])
        created_pages = json.loads(command(['gh', 'api', '--paginate', '--slurp', f'repos/{repository}/releases?per_page=100']))
        created = [entry for page in created_pages for entry in page if entry['tag_name'] == tag]
        if len(created) != 1:
            raise ValueError('created draft identity is unavailable or ambiguous')
        release = created[0]
    verify_release_record(release, tag, original_notes, release['id'])
    reconcile_assets(repository, release, directory, names, original_notes)
    # A draft may have changed while assets were checked; observe it again before publishing.
    fresh = json.loads(command(['gh', 'api', f'repos/{repository}/releases/{release["id"]}']))
    verify_release_record(fresh, tag, original_notes, release['id'])
    if fresh['draft']:
        command(['gh', 'release', 'edit', tag, '--repo', repository, '--draft=false', '--latest=false'])
    confirmed = json.loads(command(['gh', 'api', f'repos/{repository}/releases/tags/{tag}']))
    verify_release_record(confirmed, tag, original_notes, release['id'])
    if confirmed.get('draft') is not False:
        raise ValueError('stable GitHub release not confirmed')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', type=Path, required=True)
    args = parser.parse_args()
    plan = json.loads((args.directory / 'plan.json').read_text())
    recover('RbBtSn0w/Apple-iDocs', args.directory, plan,
            ['plan.json', 'artifact.json', 'package.tgz', 'idocs-darwin-arm64.tar.gz', 'idocs-darwin-arm64.sha256'])


if __name__ == '__main__':
    main()
