#!/bin/bash

[ $# -ne 2 ] && echo Usage $0 numjobs /dev/DEVICENAME && exit 1

fio \
    --bs=4k \
    --direct=1 \
    --filename=$2 \
    --filesize=30g \
    --group_reporting \
    --gtod_reduce=1 \
    --iodepth=64 \
    --ioengine=io_uring \
    --name=testrandrw \
    --numjobs=$1  \
    --randrepeat=1 \
    --readwrite=randrw \
    --rwmixread=80 \
    --runtime=600 \
    --size=30g

