# RiDDiX/docker-orcaslicer

[![GitHub Stars](https://img.shields.io/github/stars/RiDDiX/docker-orcaslicer-master.svg?style=for-the-badge&logo=github)](https://github.com/RiDDiX/docker-orcaslicer-master)
[![GitHub Release](https://img.shields.io/github/release/RiDDiX/docker-orcaslicer-master.svg?style=for-the-badge&logo=github)](https://github.com/RiDDiX/docker-orcaslicer-master/releases)
[![GitHub Package](https://img.shields.io/badge/ghcr.io-RiDDiX%2Forcaslicer-blue?style=for-the-badge&logo=github)](https://github.com/RiDDiX/docker-orcaslicer-master/pkgs/container/orcaslicer)
[![Docker Build](https://img.shields.io/github/actions/workflow/status/RiDDiX/docker-orcaslicer-master/docker-build.yml?style=for-the-badge&logo=github-actions)](https://github.com/RiDDiX/docker-orcaslicer-master/actions)

> **Fork of [linuxserver/docker-orcaslicer](https://github.com/linuxserver/docker-orcaslicer)** with Intel iGPU optimizations, stability improvements, and automatic OrcaSlicer version updates.

[OrcaSlicer](https://github.com/SoftFever/OrcaSlicer) is an open source slicer for FDM printers. This Docker container provides a web-based GUI to run OrcaSlicer in your browser.

[![orcaslicer](https://raw.githubusercontent.com/linuxserver/docker-templates/master/linuxserver.io/img/orcaslicer-logo.png)](https://github.com/SoftFever/OrcaSlicer)

## Features (Fork Enhancements)

This fork adds the following improvements over the original linuxserver.io image:

- **Intel iGPU Optimization**: Pre-installed VA-API drivers, Mesa optimizations, and Intel-specific environment variables
- **Stability Watchdog**: Automatic detection and recovery from OrcaSlicer hangs
- **Memory Management**: Prevents freezes during filament/print settings changes
- **Shader Cache Management**: Automatic cleanup to prevent memory bloat
- **Automatic Updates**: GitHub Actions workflow that builds new images when OrcaSlicer releases a new version

## Quick Start

### Docker Compose (Recommended)

```yaml
services:
  orcaslicer:
    image: ghcr.io/riddix/orcaslicer:latest
    container_name: orcaslicer
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Berlin
      - DRINODE=/dev/dri/renderD128
      - DRI_NODE=/dev/dri/renderD128
    volumes:
      - ./config:/config
    ports:
      - 3000:3000
      - 3001:3001
    devices:
      - /dev/dri:/dev/dri
    shm_size: 2gb
    restart: unless-stopped
```

### Docker CLI

```bash
docker run -d \
  --name=orcaslicer \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Europe/Berlin \
  -e DRINODE=/dev/dri/renderD128 \
  -e DRI_NODE=/dev/dri/renderD128 \
  -p 3000:3000 \
  -p 3001:3001 \
  -v /path/to/config:/config \
  --device /dev/dri:/dev/dri \
  --shm-size=2g \
  --restart unless-stopped \
  ghcr.io/riddix/orcaslicer:latest
```

## Access

The application can be accessed at:
- **HTTPS (recommended)**: https://yourhost:3001/
- **HTTP**: http://yourhost:3000/

## Intel iGPU Optimization

This container is optimized for Intel integrated GPUs. The following optimizations are included:

### Pre-installed Drivers
- `intel-media-va-driver` - Modern Intel VA-API driver (iHD)
- `i965-va-driver` - Legacy Intel VA-API driver
- Mesa Vulkan and OpenGL drivers

### Environment Variables (Auto-configured)
| Variable | Default | Description |
|----------|---------|-------------|
| `MESA_LOADER_DRIVER_OVERRIDE` | `iris` | Use Intel Iris driver |
| `LIBVA_DRIVER_NAME` | `iHD` | VA-API driver selection |
| `mesa_glthread` | `false` | Disable threaded GL for stability |

### Recommended Settings for Intel iGPU

```yaml
environment:
  - DRINODE=/dev/dri/renderD128
  - DRI_NODE=/dev/dri/renderD128
devices:
  - /dev/dri:/dev/dri
shm_size: 2gb
```

### Troubleshooting Intel iGPU

| Issue | Solution |
|-------|----------|
| OrcaSlicer hangs on settings change | The watchdog will auto-restart it. Increase `shm_size` to `4gb` |
| Older Intel GPU (pre-Skylake) | Add `-e MESA_LOADER_DRIVER_OVERRIDE=i965` |
| Disable GPU acceleration | Add `-e DISABLE_ZINK=true -e DISABLE_DRI3=true` |

## Stability Watchdog

This fork includes an automatic watchdog service that monitors OrcaSlicer and recovers from common issues.

### How It Works

The watchdog runs as a background service (`svc-orca-watchdog`) and performs the following checks every 30 seconds:

1. **Process Responsiveness**: Verifies OrcaSlicer is responding to signals
2. **Memory Usage**: Monitors RAM consumption and triggers cleanup if usage exceeds 80%
3. **CPU Hang Detection**: Detects if OrcaSlicer is stuck at 100% CPU for more than 5 minutes
4. **Shader Cache Size**: Automatically cleans Mesa shader cache when it exceeds 512MB

### Automatic Recovery Actions

| Condition | Action |
|-----------|--------|
| Process unresponsive | Graceful restart (SIGTERM → SIGKILL) |
| Memory > 80% | Clear shader cache, then restart if still high |
| CPU stuck at 100% for 5+ min | Force restart |
| Shader cache > 512MB | Automatic cleanup |

### Watchdog Logs

You can monitor the watchdog activity in the container logs:

```bash
docker logs orcaslicer 2>&1 | grep WATCHDOG
```

Example output:
```
[2026-01-16 09:00:00] WATCHDOG: Starting OrcaSlicer watchdog service
[2026-01-16 09:05:30] WATCHDOG: High memory usage detected: 2048MB (82%)
[2026-01-16 09:05:30] WATCHDOG: Clearing shader cache to free memory...
```

## Memory Management

OrcaSlicer can experience freezes when changing filament or print settings, especially with Intel iGPUs. This fork implements several memory optimizations to prevent these issues.

### OrcaSlicer Wrapper

All OrcaSlicer launches go through a wrapper script (`/usr/local/bin/orcaslicer-wrapper`) that provides:

| Feature | Description |
|---------|-------------|
| **Memory Limits** | 8GB virtual memory limit, 4GB resident memory limit |
| **Single Instance Lock** | Prevents multiple OrcaSlicer instances from running |
| **Pre-launch Cleanup** | Clears page cache before starting |
| **Exit Cleanup** | Cleans oversized shader cache (>1GB) on exit |

### Mesa/OpenGL Optimizations

The following environment variables are automatically set to improve stability:

```bash
# Reduce memory pressure
MESA_SHADER_CACHE_MAX_SIZE=512M      # Limit shader cache size
MALLOC_TRIM_THRESHOLD_=131072         # More aggressive memory trimming
MALLOC_MMAP_THRESHOLD_=131072         # Use mmap for smaller allocations

# Prevent race conditions
mesa_glthread=false                   # Disable threaded GL
__GL_MaxFramesAllowed=1               # Reduce frame buffer queue
```

### Shared Memory (shm_size)

OrcaSlicer uses shared memory for OpenGL operations. The recommended minimum is `2gb`:

```yaml
shm_size: 2gb  # Minimum recommended
shm_size: 4gb  # For complex models or frequent settings changes
```

**Symptoms of insufficient shared memory:**
- Freezes when switching filaments
- Crashes during print preview generation
- Slow UI response when changing settings

### Manual Cache Cleanup

If you experience performance degradation, you can manually clear the shader cache:

```bash
docker exec orcaslicer rm -rf /config/.cache/mesa_shader_cache/*
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PUID` | `1000` | User ID for file permissions |
| `PGID` | `1000` | Group ID for file permissions |
| `TZ` | `Etc/UTC` | Timezone |
| `DRINODE` | - | GPU render node for DRI3 (e.g., `/dev/dri/renderD128`) |
| `DRI_NODE` | - | GPU render node for VA-API encoding |
| `CUSTOM_USER` | - | HTTP Basic auth username |
| `PASSWORD` | - | HTTP Basic auth password |
| `LC_ALL` | - | Locale (e.g., `de_DE.UTF-8`) |

## Volumes

| Path | Description |
|------|-------------|
| `/config` | OrcaSlicer configuration and user data |

## Ports

| Port | Description |
|------|-------------|
| `3000` | HTTP (requires proxy for full functionality) |
| `3001` | HTTPS (recommended) |

## Building Locally

```bash
git clone https://github.com/RiDDiX/docker-orcaslicer-master.git
cd docker-orcaslicer-master
docker build -t ghcr.io/riddix/orcaslicer:latest .
```

## Automatic Updates

This repository uses GitHub Actions to automatically:
1. Check for new OrcaSlicer releases daily
2. Build and push a new Docker image to GitHub Container Registry
3. Create a GitHub release with the OrcaSlicer version tag

## Credits

- Original container by [LinuxServer.io](https://linuxserver.io)
- [OrcaSlicer](https://github.com/SoftFever/OrcaSlicer) by SoftFever
- Base image: [docker-baseimage-selkies](https://github.com/linuxserver/docker-baseimage-selkies)

## License

This project is licensed under the GPL-3.0 License - see the [LICENSE](LICENSE) file for details.

## Versions

- **15.01.26:** - Fork: Add Intel iGPU optimizations, VA-API drivers, stability watchdog, and memory management
- **01.01.26:** - Add wayland init (upstream)
- **25.11.25:** - Update project repo name (upstream)
- **15.09.25:** - Rebase to Ubuntu Noble and Selkies (upstream)
