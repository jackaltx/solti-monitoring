# NFS Client Ansible Role

This role manages NFS client installation and mount configuration for Linux systems, providing a flexible way to manage NFS mounts across different distributions.

## Overview

The role handles:
- Installation of NFS client packages
- Configuration of NFS mount points
- Support for multiple NFS shares
- Cross-platform compatibility (Debian/RedHat)

## Requirements

### Platform Support
- Debian/Ubuntu systems (uses apt)
- RedHat/CentOS systems (uses dnf)

### Prerequisites
- Systemd-based system
- Network connectivity to NFS server
- Proper firewall configuration for NFS ports

## Role Variables

### Main Control Variable
```yaml
mount_nfs_share: false    # Master switch to enable/disable NFS mounting
```

### NFS Mount Configuration
```yaml
cluster_nfs_mounts:       # Dictionary of NFS mount configurations
  mount_name:             # Unique identifier for each mount
    src: "server:/share"  # NFS server and share path
    path: "/mount/point"  # Local mount point
    opts: "mount_options" # Mount options
    state: "mounted"      # Mount state
    fstype: "nfs4"       # Filesystem type
```

### Default Mount Options
The role includes optimized default mount options:
```yaml
opts: "rw,noatime,bg,rsize=131072,wsize=131072,hard,intr,timeo=150,retrans=3"
```

These options provide:
- Read-write access
- Background mounting
- Optimized read/write sizes
- Hard mount with interrupts
- Timeout and retry settings

## Dependencies

This role has no dependencies on other Ansible roles.

## Example Playbook

Basic usage with single mount:

```yaml
- hosts: servers
  vars:
    mount_nfs_share: true
    cluster_nfs_mounts:
      data:
        src: "nfs.example.com:/data"
        path: "/mnt/data"
        opts: "rw,noatime,bg"
        state: "mounted"
        fstype: "nfs4"
  roles:
    - nfs-client
```

Advanced configuration with multiple mounts:

```yaml
- hosts: servers
  vars:
    mount_nfs_share: true
    cluster_nfs_mounts:
      data:
        src: "nfs.example.com:/data"
        path: "/mnt/data"
        opts: "rw,noatime,bg"
        state: "mounted"
        fstype: "nfs4"
      backup:
        src: "backup.example.com:/backup"
        path: "/mnt/backup"
        opts: "ro,noatime,bg"
        state: "mounted"
        fstype: "nfs4"
      temporary:
        src: "temp.example.com:/temp"
        path: "/mnt/temp"
        opts: "rw,noatime"
        state: "present"
        fstype: "nfs4"
  roles:
    - nfs-client
```

## Mount States

The role supports several mount states:
- `mounted`: Ensure mount is present and mounted
- `present`: Ensure mount is in fstab but not mounted
- `absent`: Remove mount from fstab
- `unmounted`: Ensure mount exists in fstab but is not mounted

## File Structure

```
nfs-client/
├── defaults/
│   └── main.yml           # Default variables
├── tasks/
│   └── main.yml          # Main tasks
└── vars/
    └── main.yml         # Role variables
```

## Security Considerations

- Use `root_squash` on the NFS server
- Consider using NFSv4 with Kerberos authentication
- Implement proper network segmentation
- Use read-only mounts where possible
- Configure appropriate file permissions

## Performance Tuning

The default mount options are optimized for performance:
- `rsize=131072`: Read block size
- `wsize=131072`: Write block size
- `noatime`: Disable access time updates
- `bg`: Background mounting
- `hard`: Hard mount with retries
- `timeo=150`: Timeout value
- `retrans=3`: Number of retries

## Troubleshooting

Common issues and solutions:
1. Mount fails
   - Check network connectivity
   - Verify NFS service on server
   - Check firewall rules
2. Performance issues
   - Adjust rsize/wsize values
   - Check network quality
   - Monitor server load

## License

BSD

## Author Information

Originally created by Anthropic. Extended by the community.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## Notes

- The role automatically handles package installation for different distributions
- Supports both NFSv3 and NFSv4
- Can manage multiple mounts simultaneously
- Provides flexible mount options
- Includes optimized default settings
