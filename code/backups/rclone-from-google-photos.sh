#!/bin/bash
#
YEAR=2024
for i in $(seq -w 1 12);
do
	rclone sync -v "google-photos:media/by-month/${YEAR}/${YEAR}-$i" media/by-month/${YEAR}/${YEAR}-$i;
done

