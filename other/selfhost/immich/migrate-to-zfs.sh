#!/bin/bash
set -euo pipefail

echo "=== Immich ZFS Dataset Migration ==="
echo ""

# Check if immich is stopped
if docker ps | grep -q immich; then
    echo "ERROR: Immich containers are still running!"
    echo "Run: cd /srv/selfhost/immich && docker compose down"
    exit 1
fi

echo "Step 1: Moving immich directory aside..."
sudo mv /media/simple/immich /media/simple/tmp-immich
echo "✓ Moved to /media/simple/tmp-immich"

echo ""
echo "Step 2: Setting ZFS mountpoints..."
sudo zfs set mountpoint=/media/simple/immich simple/immich
sudo zfs set mountpoint=/media/simple/immich/postgres simple/immich/postgres
echo "✓ Mountpoints configured"

echo ""
echo "Step 3: Mounting ZFS datasets..."
sudo zfs mount simple/immich
sudo zfs mount simple/immich/postgres
echo "✓ Datasets mounted"

echo ""
echo "Step 4: Verifying mounts..."
zfs list | grep immich
df -h | grep immich

echo ""
echo "Step 5: Copying data back to ZFS datasets..."
sudo rsync -av /media/simple/tmp-immich/library/ /media/simple/immich/library/
echo "✓ Library data copied"

sudo rsync -av /media/simple/tmp-immich/postgres/ /media/simple/immich/postgres/
echo "✓ Postgres data copied"

echo ""
echo "Step 6: Fixing ownership..."
sudo chown -R miguel:miguel /media/simple/immich/library
sudo chown -R 999:999 /media/simple/immich/postgres
echo "✓ Ownership fixed"

echo ""
echo "Step 7: Verifying data..."
echo "Library files: $(find /media/simple/immich/library -type f 2>/dev/null | wc -l)"
echo "Postgres files: $(find /media/simple/immich/postgres -type f 2>/dev/null | wc -l)"

echo ""
read -p "Data looks good? Remove /media/simple/tmp-immich? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo rm -rf /media/simple/tmp-immich
    echo "✓ Backup removed"
else
    echo "⚠ Backup kept at /media/simple/tmp-immich - remove manually when verified"
fi

echo ""
echo "=== Migration Complete ==="
echo "Start Immich: cd /srv/selfhost/immich && docker compose up -d"
