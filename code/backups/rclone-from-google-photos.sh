#rclone sync  -v  "google-photos:media/by-month/2023/2023-03" media/by-month/2023/2023-03
for i in $(seq 4 9); do echo rclone sync  -v  "google-photos:media/by-month/2023/2023-0$i" media/by-month/2023/2023-0$i; done
rclone sync -v google-photos:media/by-month/2023/2023-04 media/by-month/2023/2023-04
rclone sync -v google-photos:media/by-month/2023/2023-05 media/by-month/2023/2023-05
rclone sync -v google-photos:media/by-month/2023/2023-06 media/by-month/2023/2023-06
rclone sync -v google-photos:media/by-month/2023/2023-07 media/by-month/2023/2023-07
rclone sync -v google-photos:media/by-month/2023/2023-08 media/by-month/2023/2023-08
rclone sync -v google-photos:media/by-month/2023/2023-09 media/by-month/2023/2023-09


