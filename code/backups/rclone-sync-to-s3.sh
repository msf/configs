#!/bin/sh
source ./restic.env
rclone sync -P /media/weird/restic/mfilipe-backups s3-backups:mfilipe-backups/restic
