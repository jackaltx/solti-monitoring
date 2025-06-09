# Podman Command Cheatsheet

## Container Management

### Basic Operations

```bash
# List containers
podman ps                    # List running containers
podman ps -a                 # List all containers (including stopped)
podman ps --format "{{.Names}}"  # List just container names

# Container lifecycle
podman run -d IMAGE         # Run container in background
podman start CONTAINER      # Start a stopped container
podman stop CONTAINER       # Stop a running container
podman restart CONTAINER    # Restart a container
podman rm CONTAINER        # Remove a container
podman rm -f CONTAINER     # Force remove a running container
```

### Container Access

```bash
# Interactive access
podman exec -it CONTAINER /bin/bash  # Get shell in container
podman exec -it -u USER CONTAINER /bin/bash  # Shell as specific user
podman attach CONTAINER    # Attach to container's main process

# Logs and monitoring
podman logs CONTAINER      # View container logs
podman logs -f CONTAINER   # Follow container logs
podman top CONTAINER      # Show running processes in container
```

### Container Information

```bash
# Detailed information
podman inspect CONTAINER   # Show detailed container info
podman port CONTAINER     # Show port mappings
podman stats CONTAINER    # Show live resource usage
podman diff CONTAINER     # Show changes to container filesystem
```

## Image Management

### Basic Image Operations

```bash
# List and search images
podman images              # List local images
podman search IMAGE_NAME   # Search for images

# Image manipulation
podman pull IMAGE         # Pull an image
podman push IMAGE         # Push an image to registry
podman rmi IMAGE         # Remove an image
podman save -o FILE.tar IMAGE  # Save image to tar file
podman load -i FILE.tar       # Load image from tar file
```

### Building Images

```bash
# Build from Dockerfile
podman build -t NAME:TAG .     # Build from Dockerfile in current directory
podman build -f DOCKERFILE .   # Build using specific Dockerfile
```

## Network Management

### Basic Network Operations

```bash
# List and create networks
podman network ls                  # List networks
podman network create NETWORK      # Create a network
podman network rm NETWORK          # Remove a network

# Container networking
podman network connect NETWORK CONTAINER    # Connect container to network
podman network disconnect NETWORK CONTAINER # Disconnect container from network
```

## Volume Management

### Volume Operations

```bash
# Basic volume management
podman volume ls          # List volumes
podman volume create VOL  # Create a volume
podman volume rm VOL      # Remove a volume
podman volume inspect VOL # Inspect a volume
```

## System Management

### System Commands

```bash
# System maintenance
podman system prune              # Remove unused data
podman system df                 # Show disk usage
podman system info               # Show system information
podman system reset              # Reset podman storage

# Clean up
podman container prune          # Remove all stopped containers
podman image prune             # Remove unused images
podman volume prune            # Remove unused volumes
```

## Common Run Options

### Useful Container Creation Flags

```bash
# Basic options
--name NAME               # Assign name to container
-d, --detach             # Run container in background
-it                      # Interactive with terminal
--rm                     # Remove container when it exits

# Resource limits
--memory="1g"            # Memory limit
--cpus="1.5"            # CPU limit

# Network options
-p 8080:80               # Port mapping (host:container)
--network NETWORK        # Connect to network
--dns SERVER             # Set DNS servers

# Volume and mount options
-v /host:/container      # Bind mount
--volume-driver         # Specify volume driver
```

## Testing and Development

### Useful Testing Commands

```bash
# Container troubleshooting
podman exec CONTAINER ps aux     # List processes
podman exec CONTAINER netstat -tulpn  # List listening ports
podman exec CONTAINER df -h     # Check disk space

# Container inspection
podman logs --tail 50 CONTAINER  # Show last 50 log lines
podman events --filter container=CONTAINER  # Show container events
```

## Systemd Integration

### Systemd Container Management

```bash
# Generate systemd unit files
podman generate systemd CONTAINER > container.service

# Manage containers with systemd
systemctl --user start container   # Start container
systemctl --user stop container    # Stop container
systemctl --user enable container  # Enable at boot
```

## Environment Variables

### Managing Environment Variables

```bash
# Setting environment variables
--env KEY=VALUE          # Set single environment variable
--env-file FILE         # Load environment variables from file

# Viewing environment variables
podman exec CONTAINER env  # View container environment variables
```

## Notes

- Replace CONTAINER with container name or ID
- Replace IMAGE with image name or ID
- Replace NETWORK with network name
- Replace VOL with volume name
- Use `podman --help` or `podman COMMAND --help` for detailed information
