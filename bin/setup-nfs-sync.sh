#!/bin/bash
# Helper script to configure NFS sync for Obsidian test results
# Usage: source bin/setup-nfs-sync.sh

# Enable Obsidian sync
export OBSIDIAN_SYNC_ENABLED=true

# Use NFS mount instead of SSH rsync
export OBSIDIAN_NFS_MOUNT=/mnt/SoltiMonitorTesting

# Target UID/GID for NFS files (Obsidian container user)
export OBSIDIAN_NFS_UID=568
export OBSIDIAN_NFS_GID=568

# SSH connection for remote ownership fix (lavadmin has NOPASSWD sudo)
export OBSIDIAN_SSH_HOST=lavadmin@truenas.jackaltx.com
export OBSIDIAN_REMOTE_PATH=/mnt/zpool/Docker/Stacks/obsidian/SoltiMonitorTesting

echo "Obsidian NFS sync configured:"
echo "  Local NFS mount: ${OBSIDIAN_NFS_MOUNT}"
echo "  Remote path: ${OBSIDIAN_SSH_HOST}:${OBSIDIAN_REMOTE_PATH}"
echo "  Target ownership: ${OBSIDIAN_NFS_UID}:${OBSIDIAN_NFS_GID}"
echo ""
echo "Files will be synced via NFS, ownership fixed via SSH (lavadmin has NOPASSWD sudo)"
echo ""
echo "To use SSH rsync instead, unset OBSIDIAN_NFS_MOUNT:"
echo "  unset OBSIDIAN_NFS_MOUNT"
echo "  export OBSIDIAN_SYNC_TARGET=user@server:/path/to/vault/"
