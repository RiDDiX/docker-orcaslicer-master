# syntax=docker/dockerfile:1

FROM ghcr.io/linuxserver/baseimage-selkies:ubuntunoble

# set version label
ARG BUILD_DATE
ARG VERSION
ARG ORCASLICER_VERSION
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="thelamer"

# title
ENV TITLE=OrcaSlicer \
    SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
    NO_GAMEPAD=true \
    # Intel iGPU optimizations
    MESA_LOADER_DRIVER_OVERRIDE=iris \
    INTEL_DEBUG=norbc \
    vblank_mode=0 \
    MESA_GL_VERSION_OVERRIDE=4.5 \
    MESA_GLSL_VERSION_OVERRIDE=450 \
    LIBGL_DRI3_DISABLE=0 \
    # Memory management for OpenGL stability
    MALLOC_TRIM_THRESHOLD_=131072 \
    MALLOC_MMAP_THRESHOLD_=131072 \
    # Reduce Mesa shader cache memory pressure
    MESA_SHADER_CACHE_MAX_SIZE=512M \
    MESA_SHADER_CACHE_DISABLE=false

RUN \
  echo "**** add icon ****" && \
  curl -o \
    /usr/share/selkies/www/icon.png \
    https://raw.githubusercontent.com/linuxserver/docker-templates/master/linuxserver.io/img/orcaslicer-logo.png && \
  echo "**** install Intel iGPU packages ****" && \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive \
  apt-get install --no-install-recommends -y \
    intel-media-va-driver \
    i965-va-driver \
    vainfo \
    intel-gpu-tools \
    libva2 \
    libva-drm2 \
    libva-x11-2 \
    libvdpau-va-gl1 \
    mesa-va-drivers \
    mesa-vulkan-drivers \
    libgl1-mesa-dri \
    libglx-mesa0 \
    libegl-mesa0 \
    mesa-utils && \
  echo "**** install Mozilla Firefox from official repo ****" && \
  install -d -m 0755 /etc/apt/keyrings && \
  curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg | gpg --dearmor -o /etc/apt/keyrings/packages.mozilla.org.gpg && \
  echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.gpg] https://packages.mozilla.org/apt mozilla main" > /etc/apt/sources.list.d/mozilla.list && \
  echo 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000' > /etc/apt/preferences.d/mozilla && \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive \
  apt-get install --no-install-recommends -y \
    firefox \
    gstreamer1.0-alsa \
    gstreamer1.0-gl \
    gstreamer1.0-gtk3 \
    gstreamer1.0-libav \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-pulseaudio \
    gstreamer1.0-qt5 \
    gstreamer1.0-tools \
    gstreamer1.0-x \
    libgstreamer-plugins-bad1.0 \
    libwebkit2gtk-4.1-0 \
    libwx-perl && \
  echo "**** install orcaslicer from appimage ****" && \
  if [ -z ${ORCASLICER_VERSION+x} ]; then \
    ORCASLICER_VERSION=$(curl -sX GET "https://api.github.com/repos/OrcaSlicer/OrcaSlicer/releases/latest" \
    | awk '/tag_name/{print $4;exit}' FS='[""]'); \
  fi && \
  RELEASE_URL=$(curl -sX GET "https://api.github.com/repos/OrcaSlicer/OrcaSlicer/releases/latest"     | awk '/url/{print $4;exit}' FS='[""]') && \
  DOWNLOAD_URL=$(curl -sX GET "${RELEASE_URL}" | awk '/browser_download_url.*Ubuntu2404/{print $4;exit}' FS='[""]') && \
  cd /tmp && \
  curl -o \
    /tmp/orca.app -L \
    "${DOWNLOAD_URL}" && \
  chmod +x /tmp/orca.app && \
  ./orca.app --appimage-extract && \
  mv squashfs-root /opt/orcaslicer && \
  localedef -i en_GB -f UTF-8 en_GB.UTF-8 && \
  printf "Linuxserver.io version: ${VERSION}\nBuild-date: ${BUILD_DATE}" > /build_version && \
  echo "**** cleanup ****" && \
  apt-get autoclean && \
  rm -rf \
    /config/.cache \
    /config/.launchpadlib \
    /var/lib/apt/lists/* \
    /var/tmp/* \
    /tmp/*

# add local files
COPY /root /

# make scripts executable
RUN chmod +x /usr/local/bin/orcaslicer-wrapper && \
    chmod +x /etc/s6-overlay/s6-rc.d/init-intel-gpu/run && \
    chmod +x /etc/s6-overlay/s6-rc.d/svc-orca-watchdog/run

# ports and volumes
EXPOSE 3001
VOLUME /config
