#!/bin/sh
source ./restic.env
rclone sync -P /media/simple/restic/mfilipe-backups cloudflare-r2-backups:backups/restic
