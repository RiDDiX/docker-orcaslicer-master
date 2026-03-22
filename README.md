# RiDDiX/docker-orcaslicer

[![GitHub Stars](https://img.shields.io/github/stars/RiDDiX/docker-orcaslicer-master.svg?style=for-the-badge&logo=github)](https://github.com/RiDDiX/docker-orcaslicer-master)
[![GitHub Release](https://img.shields.io/github/release/RiDDiX/docker-orcaslicer-master.svg?style=for-the-badge&logo=github)](https://github.com/RiDDiX/docker-orcaslicer-master/releases)
[![GitHub Package](https://img.shields.io/badge/ghcr.io-RiDDiX%2Forcaslicer-blue?style=for-the-badge&logo=github)](https://github.com/RiDDiX/docker-orcaslicer-master/pkgs/container/orcaslicer)
[![Docker Build](https://img.shields.io/github/actions/workflow/status/RiDDiX/docker-orcaslicer-master/docker-build.yml?style=for-the-badge&logo=github-actions)](https://github.com/RiDDiX/docker-orcaslicer-master/actions)

> **Fork of [linuxserver/docker-orcaslicer](https://github.com/linuxserver/docker-orcaslicer)** with multi-GPU support (Intel, AMD, Nvidia), stability improvements, and automatic OrcaSlicer version updates.

[OrcaSlicer](https://github.com/SoftFever/OrcaSlicer) is an open source slicer for FDM printers. This Docker container provides a web-based GUI to run OrcaSlicer in your browser.

[![orcaslicer](https://raw.githubusercontent.com/linuxserver/docker-templates/master/linuxserver.io/img/orcaslicer-logo.png)](https://github.com/SoftFever/OrcaSlicer)

## Features (Fork Enhancements)

This fork adds the following improvements over the original linuxserver.io image:

- **Multi-GPU Support**: Automatic detection and configuration for Intel, AMD, and Nvidia GPUs — including multi-GPU systems
- **Smart Render Node Selection**: Auto-detects the correct Mesa-compatible render node on multi-GPU hosts (e.g. Nvidia discrete + AMD/Intel integrated)
- **Devices Dialog Fix**: Prevents WebKit2GTK DMA-BUF crashes when opening the Devices tab
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

> **Note:** The container automatically detects your GPU and selects the correct render node. You do **not** need to set `DRINODE` manually unless you want to override auto-detection (see [Manual GPU Override](#manual-gpu-override)).

### Docker CLI

```bash
docker run -d \
  --name=orcaslicer \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Europe/Berlin \
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

## GPU Acceleration

This container supports **Intel, AMD, and Nvidia GPUs** with automatic detection and optimized configuration.

### Supported GPUs

| Vendor | Driver | Auto-configured |
|--------|--------|-----------------|
| **Intel** | iris (Gen8+), i965 (older) | ✅ `MESA_LOADER_DRIVER_OVERRIDE=iris` |
| **AMD** | radeonsi (OpenGL), RADV (Vulkan) | ✅ `MESA_LOADER_DRIVER_OVERRIDE=radeonsi` |
| **Nvidia** | Proprietary driver | ✅ Requires `nvidia-container-toolkit` on host |

### Pre-installed Drivers
- **Intel**: `intel-media-va-driver`, `i965-va-driver`
- **AMD**: `libdrm-amdgpu1`, `mesa-vulkan-drivers` (RADV)
- **Common**: Mesa OpenGL, VA-API, Vulkan tools

### Intel GPU Configuration

Works out of the box — the container auto-detects Intel GPUs (iris for Gen8+).

```yaml
services:
  orcaslicer:
    image: ghcr.io/riddix/orcaslicer:latest
    devices:
      - /dev/dri:/dev/dri
    shm_size: 2gb
```

For older Intel GPUs (pre-Skylake), override the driver:
```yaml
environment:
  - GPU_VENDOR_OVERRIDE=intel
  - MESA_LOADER_DRIVER_OVERRIDE=i965
```

### AMD GPU Configuration

Works out of the box — the container auto-detects AMD GPUs (radeonsi).

```yaml
services:
  orcaslicer:
    image: ghcr.io/riddix/orcaslicer:latest
    devices:
      - /dev/dri:/dev/dri
      - /dev/kfd:/dev/kfd  # Optional: For ROCm/OpenCL
    shm_size: 2gb
    group_add:
      - video
      - render
```

### Nvidia GPU Configuration

**Host requirements:**
1. Install [nvidia-container-toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) on the host
2. Configure the Docker runtime: `sudo nvidia-ctk runtime configure --runtime=docker`
3. Restart Docker: `sudo systemctl restart docker`

```yaml
services:
  orcaslicer:
    image: ghcr.io/riddix/orcaslicer:latest
    runtime: nvidia
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
      - NVIDIA_DRIVER_CAPABILITIES=all
    devices:
      - /dev/dri:/dev/dri
    shm_size: 2gb
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu, utility, compute, graphics, display]
```

> **Multi-GPU hosts (e.g. Nvidia + Intel/AMD):** The container automatically selects the Mesa-compatible GPU (Intel/AMD) for rendering if `nvidia-container-toolkit` is not installed. When `nvidia-container-toolkit` is installed and the `nvidia` runtime is configured, the Nvidia GPU is used instead.

### Manual GPU Override

If auto-detection fails, force a specific GPU vendor:

```yaml
environment:
  - GPU_VENDOR_OVERRIDE=intel   # or: amd, nvidia
```

### Troubleshooting GPU

| Issue | Solution |
|-------|----------|
| OrcaSlicer hangs on settings change | Increase `shm_size` to `4gb` |
| **Crash when clicking Devices** | Known upstream OrcaSlicer bug ([#8942](https://github.com/OrcaSlicer/OrcaSlicer/issues/8942), [#10756](https://github.com/OrcaSlicer/OrcaSlicer/issues/10756)). Affects all Linux builds when a BambuLab account is signed in or a Klipper printer is configured. The watchdog auto-restarts OrcaSlicer after the crash. |
| Wrong GPU selected on multi-GPU host | Set `DRINODE=/dev/dri/renderD12X` to the correct render node (check `ls -la /dev/dri/by-path/` on host) |
| Older Intel GPU (pre-Skylake) | Add `-e MESA_LOADER_DRIVER_OVERRIDE=i965` |
| AMD GPU not detected | Add `-e GPU_VENDOR_OVERRIDE=amd` |
| Nvidia: no GPU acceleration | Ensure `nvidia-container-toolkit` is installed and Docker is configured (see above) |
| Nvidia DRM node used without toolkit | The container auto-skips Nvidia render nodes when `nvidia-container-toolkit` is not present |
| Disable GPU acceleration entirely | Add `-e LIBGL_ALWAYS_SOFTWARE=1` |

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
| **Configurable Memory Limits** | Set via `ORCA_MEM_LIMIT_GB` environment variable (default: unlimited) |
| **Single Instance Lock** | Prevents multiple OrcaSlicer instances from running |
| **Pre-launch Cleanup** | Clears page cache before starting |
| **Exit Cleanup** | Cleans oversized shader cache (>1GB) on exit |

### Memory Configuration

For complex STL files, OrcaSlicer may need significant RAM. You can configure memory limits:

```yaml
environment:
  - ORCA_MEM_LIMIT_GB=unlimited  # No limit (default) - recommended for complex models
  - ORCA_MEM_LIMIT_GB=16         # Limit to 16GB
  - ORCA_MEM_LIMIT_GB=32         # Limit to 32GB
```

You can also limit Docker container memory directly:

```yaml
services:
  orcaslicer:
    image: ghcr.io/riddix/orcaslicer:latest
    mem_limit: 16g           # Hard limit for container
    mem_reservation: 4g      # Soft limit (guaranteed minimum)
```

**Recommendation**: For slicing complex models, use `ORCA_MEM_LIMIT_GB=unlimited` and let Docker manage memory with `mem_limit`.

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
| `DRINODE` | auto-detected | GPU render node override (e.g., `/dev/dri/renderD128`). Auto-detected if not set. |
| `DRI_NODE` | auto-detected | GPU render node override for VA-API encoding. Auto-detected if not set. |
| `GPU_VENDOR_OVERRIDE` | auto-detected | Force GPU vendor: `intel`, `amd`, or `nvidia` |
| `NVIDIA_VISIBLE_DEVICES` | - | Set to `all` when using Nvidia runtime |
| `NVIDIA_DRIVER_CAPABILITIES` | - | Set to `all` when using Nvidia runtime |
| `WEBKIT_DISABLE_DMABUF_RENDERER` | `1` | Prevents WebKit2GTK DMA-BUF crash in Devices dialog |
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

## Available Docker Tags

This image provides multiple tags for different OrcaSlicer release channels:

| Tag | Description |
|-----|-------------|
| `latest` | Latest stable OrcaSlicer release (recommended) |
| `nightly` | Latest nightly/pre-release build |
| `beta` | Latest beta release |
| `v2.3.0`, `v2.3.0-beta2`, etc. | Specific OrcaSlicer version |

### Pull Examples

```bash
# Latest stable release
docker pull ghcr.io/riddix/orcaslicer:latest

# Nightly build (may be unstable)
docker pull ghcr.io/riddix/orcaslicer:nightly

# Specific version
docker pull ghcr.io/riddix/orcaslicer:v2.3.0
```

## Building Locally

```bash
git clone https://github.com/RiDDiX/docker-orcaslicer-master.git
cd docker-orcaslicer-master

# Build latest stable
docker build -t ghcr.io/riddix/orcaslicer:latest .

# Build specific version
docker build --build-arg ORCASLICER_VERSION=v2.3.0-beta2 -t ghcr.io/riddix/orcaslicer:v2.3.0-beta2 .

# Build nightly
docker build --build-arg ORCASLICER_VERSION=nightly -t ghcr.io/riddix/orcaslicer:nightly .
```

## Automatic Updates

This repository uses GitHub Actions to automatically:

1. **Check for new releases every 6 hours** (stable and nightly)
2. **Build and push** new Docker images to GitHub Container Registry
3. **Create GitHub releases** with the OrcaSlicer version tag
4. **Tag images correctly** (`latest`, `nightly`, or specific version)

### Manual Workflow Dispatch

You can manually trigger builds via GitHub Actions with different release types:

| Release Type | Description |
|--------------|-------------|
| `latest` | Build the latest stable release |
| `nightly` | Build the latest nightly/pre-release |
| `beta` | Build the latest beta release |
| `custom` | Build a specific version (e.g., `v2.3.0-beta2`) |

## Credits

- Original container by [LinuxServer.io](https://linuxserver.io)
- [OrcaSlicer](https://github.com/SoftFever/OrcaSlicer) by SoftFever
- Base image: [docker-baseimage-selkies](https://github.com/linuxserver/docker-baseimage-selkies)

## License

This project is licensed under the GPL-3.0 License - see the [LICENSE](LICENSE) file for details.

## Versions

- **22.03.26:** - Fix Devices dialog crash (WebKit2GTK DMA-BUF), add multi-GPU auto-detection, smart render node selection, USB device enumeration support
- **15.01.26:** - Fork: Add GPU optimizations, VA-API drivers, stability watchdog, and memory management
- **01.01.26:** - Add wayland init (upstream)
- **25.11.25:** - Update project repo name (upstream)
- **15.09.25:** - Rebase to Ubuntu Noble and Selkies (upstream)
