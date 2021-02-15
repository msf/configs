This folder is used as base mounting point for Gluster bricks.
Expectations:
- this directory belongs to an encrypted mountpoint and is used to bootstrap data drives
- there are multiple data drives, each will be assigned a label
- data drives will be encrypted w/ passphrase, stored with their respective name.


You'll find here the following files and directories:
- hdd1/
- hdd1_key
- ssd1/
- ssh1_key

Where hdd1 is the disk label of a whole disk.
hdd1 will be encrypted with hdd1_key

Each of these directories (hdd1/, ssd1/) will contain a directory for the Gluster volume they belong to.
This is so that, if the drives aren't mounted properly, the path /data/hdd1/vol1 won't be present and therefore will produce an explicit error (instead of accidentally using the wrong drive for this data storage)

