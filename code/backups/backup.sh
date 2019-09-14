#!/bin/sh
set -e

source ./restic.env
python3 backup-to-restic.py
