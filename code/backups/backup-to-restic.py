import os
from subprocess import run


DIRPATH = "/media/simple/syncthing"
BLACKLIST = { ".zfs", }


def main():
    run_backup(DIRPATH, ["syncthing"])


def run_backup(basedir_path, tags):
    dirs = get_dirname_and_tag_list(basedir_path)
    for dname, tag in dirs:
        cmdline = get_restic_cmdline(basedir_path, dname, tag, tags)
        print(f"Running: {' '.join(cmdline)}")
        rc = run(cmdline, capture_output=True)
        if len(rc.stdout) > 0:
            print(f"stdout: {rc.stdout.decode('utf-8')}")
        if len(rc.stderr) > 0:
            print(f"stderr: {rc.stderr.decode('utf-8')}")
        if rc.returncode != 0:
            raise Exception("backup failed")


def get_dirname_and_tag_list(path):
    out = []
    for dname in os.listdir(path):
        if dname in BLACKLIST:
            continue
        tag = dname.replace(" ", "_")
        out.append((dname, tag))
    return out


def get_restic_cmdline(path, dirname, dir_tag, tags):
    cmd = [
        "restic",
        "backup",
        "--quiet",
    ]
    dtags = [ i for i in tags ] + [ dir_tag ]
    for tag in dtags:
        cmd.append("--tag")
        cmd.append(tag)
    cmd.append(path + '/' + dirname)
    return cmd


if __name__ == "__main__":
    main()
