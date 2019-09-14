#!/bin/sh
source ./restic.env
rclone sync  -P s3-backups:mfilipe-backups/restic mfilipe-backups
