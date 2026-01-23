#!/usr/bin/env python3
import sys
from pathlib import Path
from subprocess import run
from datetime import datetime


DIRPATHS = {
    "/media/simple/backups/BACKUPS/fotos": ["fotos"],
    "/media/simple/backups/BACKUPS/GooglePhotosBackup": ["fotos", "googlePhotos"],
}
BLACKLIST = {".zfs", "README.md"}


def main():
    dry_run = "--dry-run" in sys.argv
    if dry_run:
        print("DRY RUN MODE - no backups will be created\n")

    for d, tags in DIRPATHS.items():
        basedir = Path(d)
        if not basedir.exists():
            print(f"Skipping {d} (does not exist)")
            continue
        run_backup(basedir, tags, dry_run)


def run_backup(basedir_path, tags, dry_run):
    dirs = get_dirname_and_tag_list(basedir_path)
    for dname, tag in dirs:
        cmdline = get_restic_cmdline(basedir_path, dname, tag, tags, dry_run)
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] Running: {' '.join(cmdline)}")

        if dry_run:
            continue

        rc = run(cmdline)
        if rc.returncode != 0:
            print(f"ERROR: backup failed for {dname}", file=sys.stderr)
            sys.exit(1)


def get_dirname_and_tag_list(path):
    out = []
    for entry in sorted(path.iterdir()):
        if not entry.is_dir() or entry.name in BLACKLIST:
            continue
        tag = entry.name.replace(" ", "_")
        out.append((entry.name, tag))
    return out


def get_restic_cmdline(path, dirname, dir_tag, tags, dry_run):
    cmd = ["restic", "backup"]
    if not dry_run:
        cmd.append("--quiet")

    dtags = list(tags) + [dir_tag]
    for tag in dtags:
        cmd.extend(["--tag", tag])

    cmd.append(str(path / dirname))
    return cmd


if __name__ == "__main__":
    main()
