#!/bin/bash

[ $# -ne 3 ] && echo Usage $0 numjobs /dev/DEVICENAME BLOCKSIZE && exit 1

fio --readonly --name=onessd \
    --filename=$2 \
    --filesize=30g --rw=randread --bs=$3 --direct=1 --overwrite=0 \
    --numjobs=$1 --iodepth=32 --time_based=1 --runtime=360 \
    --ioengine=io_uring \
    --registerfiles --fixedbufs \
    --gtod_reduce=1 --group_reporting

