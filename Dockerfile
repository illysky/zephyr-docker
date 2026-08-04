FROM ubuntu:24.04 AS base

########################################################################################
# Create a non-root user for this images. This can be overridden by build arguements, 
# and idealy mirror the host to avoid file and folder permission issues.
########################################################################################
ARG USERNAME=development
ARG USER_UID=1000
ARG USER_GID=$USER_UID
ARG ZEPHYR_TOOLCHAIN_VERSION=1.0.1
ARG WEST_VERSION=1.5.0
ARG JLINK_VERSION=V960
ARG LINKSERVER_VERSION=26.5.59
ARG GO_VERSION=1.26.5
ARG TIO_VERSION=v3.9
ARG ANDROID_CMDLINE_TOOLS_VERSION=11076708
ARG ANDROID_BUILD_TOOLS_VERSION=34.0.0
ARG ANDROID_PLATFORM_VERSION=34
ARG PROTOC_VERSION=33.2
ARG FIXUID_VERSION=0.6.0
########################################################################################
# LinkServer (NXP MCU-Link / CMSIS-DAP debug host tools) release notes/downloads:
# https://mcuxpresso.nxp.com/linkserver/latest/
########################################################################################

ARG arch=amd64
ARG crossarch=arm-zephyr-eabi
# Extra Zephyr SDK GNU toolchains installed alongside crossarch, space-separated
# (setup.sh -t <name>, repeated). Defaults to the Xtensa DSP cores on the NXP
# MIMXRT700-EVK (RT798S) used by illysky/zephyr-examples' apps/rt700/* —
# without these, west build fails for the hifi4/hifi1 sysbuild images with
# "C compiler ... not found" since only crossarch gets installed otherwise.
# Full toolchain list: <sdk-dir>/setup.sh (no args) or sdk_gnu_toolchains.
ARG extra_toolchains="xtensa-nxp_rt700_hifi4_zephyr-elf xtensa-nxp_rt700_hifi1_zephyr-elf"
ENV DEBIAN_FRONTEND=noninteractive
ARG ZEPHYR_TOOLCHAIN_ARCHIVE_FORMAT=xz
########################################################################################
# Begin with some root user things to allow sudoers
########################################################################################
USER root
RUN apt-get -y update && \
    apt-get -y upgrade && \
    apt-get -y install sudo
########################################################################################
# Add our non-root user (host mirror) and give them sudo priviledges 
########################################################################################
RUN userdel ubuntu 2>/dev/null || true && \
    groupdel ubuntu 2>/dev/null || true && \
    groupadd --gid $USER_GID $USERNAME && \
    useradd -ms /bin/bash --uid $USER_UID --gid $USER_GID -m $USERNAME && \
    usermod -aG sudo $USERNAME && \
    usermod -aG root $USERNAME && \
    usermod -aG dialout $USERNAME

########################################################################################
# Disable asking for a password on sudo
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
########################################################################################
########################################################################################
# Switch to USER, create work directory and update PATH
########################################################################################
USER $USERNAME
WORKDIR /workdir
ENV PATH="/home/${USERNAME}/.local/bin:${PATH}"    
RUN mkdir /workdir/.cache && \
    sudo apt-get -y update && \
    sudo apt-get -y upgrade && \
    sudo apt-get -y install \
        wget \
        python3-pip \
        python3-venv \
        software-properties-common \
        ninja-build \
        gperf \
        git \
        unzip \
        gn \
        libncurses-dev \
        libyaml-dev \
        libfdt-dev \
        libusb-1.0-0-dev udev \
        device-tree-compiler \
        xz-utils \
        file \
        ruby \
        openocd \
        meson \
        libglib2.0-dev \
        libudev-dev \
        liblua5.4-dev \
        lua5.4 && \
    case $arch in \
    "amd64") \
        sudo apt-get -y install gcc-multilib \
        ;; \
    esac && \
    sudo apt-get -y clean && sudo apt-get -y autoremove
########################################################################################
# Python 3.13 via deadsnakes PPA (Ubuntu 24.04 ships 3.12; 3.13 needs the PPA)
########################################################################################
RUN sudo add-apt-repository -y ppa:deadsnakes/ppa && \
    sudo apt-get -y update && \
    sudo apt-get -y install --no-install-recommends \
        python3.13 \
        python3.13-dev \
        python3.13-venv && \
    sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.13 2 && \
    sudo update-alternatives --set python3 /usr/bin/python3.13 && \
    wget -q https://bootstrap.pypa.io/get-pip.py -O /tmp/get-pip.py && \
    python3 /tmp/get-pip.py --break-system-packages && \
    rm /tmp/get-pip.py && \
    sudo apt-get -y clean && sudo apt-get -y autoremove
########################################################################################
# Install GitHub CLI (gh)
########################################################################################
RUN sudo mkdir -p -m 755 /etc/apt/keyrings \
    && out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    && cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && sudo apt-get -y update && sudo apt-get -y install gh \
    && sudo apt-get -y clean && sudo apt-get -y autoremove
########################################################################################
# Install all the Python Tools
########################################################################################
RUN python3 -m pip install --break-system-packages -U pip && \
    python3 -m pip install --break-system-packages -U pipx && \
    python3 -m pip install --break-system-packages uv && \
    python3 -m pip install --break-system-packages -U setuptools && \
    python3 -m pip install --break-system-packages 'cmake>=3.20.0' wheel && \
    python3 -m pip install --break-system-packages -U "west==${WEST_VERSION}" && \
    python3 -m pip install --break-system-packages pc_ble_driver_py && \
    # Newer PIP will not overwrite distutils, so upgrade PyYAML manually
    python3 -m pip install --break-system-packages --ignore-installed -U PyYAML && \
    ########################################################################################
    # Enable Clang Support
    ########################################################################################
    python3 -m pip install --break-system-packages -U six && \
    sudo apt-get -y install clang-format && \
    sudo apt-get -y install libsm6 libgl1 && \
    wget -qO- https://raw.githubusercontent.com/zephyrproject-rtos/zephyr/main/.clang-format > /workdir/.clang-format && \
    ########################################################################################
    # Install SEGGER JLink V9.40
    ########################################################################################
    echo "Host architecture: $arch" && \
    case $arch in \
        "amd64") \
            JLINK_ARCH="x86_64" \
            ;; \
        "arm64") \
            JLINK_ARCH="arm64" \
            ;; \
    esac && \
    JLINK_URL="https://www.segger.com/downloads/jlink/JLink_Linux_${JLINK_VERSION}_${JLINK_ARCH}.tgz" && \
    echo "Downloading JLink from: ${JLINK_URL}" && \
    mkdir tmp && cd tmp && \
    wget --post-data 'accept_license_agreement=accepted' -O JLink.tgz "${JLINK_URL}" && \
    sudo mkdir -p /opt/SEGGER && \
    sudo tar xzf JLink.tgz -C /opt/SEGGER && \
    sudo mv /opt/SEGGER/JLink* /opt/SEGGER/JLink && \
    sudo cp /opt/SEGGER/JLink/99-jlink.rules /etc/udev/rules.d/99-jlink.rules && \
    cd .. && rm -rf tmp && \
    ########################################################################################
    # Install NXP LinkServer (MCU-Link CMSIS-DAP/J-Link debug host tools + firmware
    # switch scripts). Bundles the MCU-LINK_installer (program_CMSIS/program_JLINK)
    # used to flip an onboard MCU-Link probe (e.g. MIMXRT700-EVK) between CMSIS-DAP
    # and SEGGER J-Link firmware. amd64 only — NXP does not ship an arm64 Linux build.
    # https://mcuxpresso.nxp.com/linkserver/latest/
    ########################################################################################
    if [ "$arch" = "amd64" ]; then \
        # LinkServer's postinst runs `udevadm control --reload`, which fails
        # in a Docker build (no udevd running) with "Failed to send reload
        # request", aborting the install even though the files are already
        # unpacked fine. Stub out udevadm for the duration of the install. \
        sudo mv /usr/bin/udevadm /usr/bin/udevadm.real && \
        printf '#!/bin/sh\nexit 0\n' | sudo tee /usr/bin/udevadm > /dev/null && \
        sudo chmod +x /usr/bin/udevadm && \
        mkdir /tmp/linkserver && cd /tmp/linkserver && \
        wget -q "https://www.nxp.com/lgfiles/updates/mcuxpresso/LinkServer_${LINKSERVER_VERSION}.x86_64.deb.bin" \
            -O LinkServer.deb.bin && \
        chmod a+x LinkServer.deb.bin && \
        sudo ./LinkServer.deb.bin acceptLicense skipIdeSelect && \
        cd /workdir && rm -rf /tmp/linkserver && \
        sudo mv /usr/bin/udevadm.real /usr/bin/udevadm ; \
    fi && \
    ########################################################################################
    # Zephyr Toolchain
    # Releases: https://github.com/zephyrproject-rtos/sdk-ng/releases
    ########################################################################################
    echo "Host architecture: ${arch}" && \
    echo "Target architecture: ${crossarch}" && \
    echo "Zephyr Toolchain version: ${ZEPHYR_TOOLCHAIN_VERSION}" && \
    case $arch in \
        "amd64") \
            ZEPHYR_MINIMAL_BUNDLE_URL="https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_TOOLCHAIN_VERSION}/zephyr-sdk-${ZEPHYR_TOOLCHAIN_VERSION}_linux-x86_64_minimal.tar.${ZEPHYR_TOOLCHAIN_ARCHIVE_FORMAT}" \
            ;; \
        "arm64") \
            ZEPHYR_MINIMAL_BUNDLE_URL="https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_TOOLCHAIN_VERSION}/zephyr-sdk-${ZEPHYR_TOOLCHAIN_VERSION}_macos-aarch64_minimal.tar.${ZEPHYR_TOOLCHAIN_ARCHIVE_FORMAT}" \
            ;; \
        *) \
            echo "Unsupported host architecture: \"${arch}\"" >&2 && \
            exit 1 ;; \
    esac && \
    echo "Install Zephyr SDK from ZEPHYR_MINIMAL_BUNDLE_URL=${ZEPHYR_MINIMAL_BUNDLE_URL}" && \
    wget -q --tries=3 "${ZEPHYR_MINIMAL_BUNDLE_URL}" -O /tmp/zephyr-sdk-bundle.tar.${ZEPHYR_TOOLCHAIN_ARCHIVE_FORMAT} && \
    case $ZEPHYR_TOOLCHAIN_ARCHIVE_FORMAT in \
        "gz") \
            tar xzf /tmp/zephyr-sdk-bundle.tar.${ZEPHYR_TOOLCHAIN_ARCHIVE_FORMAT};; \
        *) \
            tar xJf /tmp/zephyr-sdk-bundle.tar.${ZEPHYR_TOOLCHAIN_ARCHIVE_FORMAT};; \
    esac && \
    rm /tmp/zephyr-sdk-bundle.tar.${ZEPHYR_TOOLCHAIN_ARCHIVE_FORMAT} && \
    mv /workdir/zephyr-sdk-${ZEPHYR_TOOLCHAIN_VERSION} /workdir/zephyr-sdk && cd /workdir/zephyr-sdk && \
    case $arch in \
        "arm64") \
            ./setup.sh -t aarch64-zephyr-elf -c \
            ;; \
        *) \
            toolchain_args="-t ${crossarch}" && \
            for t in ${extra_toolchains}; do toolchain_args="${toolchain_args} -t ${t}"; done && \
            yes | ./setup.sh ${toolchain_args} \
            ;; \
    esac && \
    #########################################################################################
    # Install Python 3.8 for older toolchain versions
    #########################################################################################
    if [ $(expr match "$ZEPHYR_TOOLCHAIN_VERSION" "0\.14\.*") -ne 0 ]; then \
        sudo apt-get -y install software-properties-common && \
        sudo add-apt-repository -y ppa:deadsnakes/ppa && \
        sudo apt-get -y update && \
        sudo apt-get -y install python3.8 python3.8-dev && \
        python3.8 --version; \
    fi 
########################################################################################
# udev rules for NXP CMSIS-DAP / MCU-Link debug probes (normal + ISP/DFU-mode PIDs),
# so LinkServer/pyocd/openocd can access the probe as a non-root user inside the
# container (mirrors host udev rules — still needed if /dev is bind-mounted without
# --privileged, and documents the required host-side rule for reference).
########################################################################################
RUN printf '%s\n' \
      '# NXP CMSIS-DAP debug probes (MCU-Link onboard/standalone, LPC-Link2)' \
      'SUBSYSTEM=="usb", ATTR{idVendor}=="1fc9", ATTR{idProduct}=="0143", MODE="0666", GROUP="plugdev"' \
      'SUBSYSTEM=="usb", ATTR{idVendor}=="1fc9", ATTR{idProduct}=="0090", MODE="0666", GROUP="plugdev"' \
      '# MCU-Link ISP/DFU-mode PIDs (used only while flashing probe firmware)' \
      'SUBSYSTEM=="usb", ATTR{idVendor}=="1fc9", ATTR{idProduct}=="0021", MODE="0666", GROUP="plugdev"' \
      'SUBSYSTEM=="usb", ATTR{idVendor}=="1fc9", ATTR{idProduct}=="0022", MODE="0666", GROUP="plugdev"' \
      | sudo tee /etc/udev/rules.d/60-nxp-debug-probes.rules > /dev/null
########################################################################################
# Install Go, mcumgr CLI, and tio (serial terminal)
########################################################################################
RUN case $arch in \
        "amd64") GO_ARCH="amd64" ;; \
        "arm64") GO_ARCH="arm64" ;; \
    esac && \
    ########################################################################################
    # Install Go (required for mcumgr)
    ########################################################################################
    wget -q "https://go.dev/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz" -O /tmp/go.tar.gz && \
    sudo tar -C /usr/local -xzf /tmp/go.tar.gz && \
    rm /tmp/go.tar.gz && \
    ########################################################################################
    # Install mcumgr CLI (Zephyr device management over serial/BLE/UDP)
    ########################################################################################
    /usr/local/go/bin/go install github.com/apache/mynewt-mcumgr-cli/mcumgr@latest && \
    ########################################################################################
    # Install tio from source (latest release - v3.x has auto-reconnect, timestamps, etc.)
    # apt version on Ubuntu 22.04 is only 1.32
    ########################################################################################
    git clone --depth=1 --branch ${TIO_VERSION} https://github.com/tio/tio.git /tmp/tio && \
    cd /tmp/tio && \
    meson setup build && \
    ninja -C build && \
    sudo ninja -C build install && \
    rm -rf /tmp/tio

########################################################################################
# protoc (Protocol Buffers compiler) — install from official GitHub release.
# The apt protobuf-compiler on Ubuntu 24.04 is too old to support proto3 optional
# fields required by nanopb 0.4.9 (needs --experimental_allow_proto3_optional).
# Version 33.2 matches nanopb 0.4.9 used in the beeline firmware build.
########################################################################################
RUN case $arch in \
        "amd64") PROTOC_ARCH="x86_64" ;; \
        "arm64") PROTOC_ARCH="aarch_64" ;; \
    esac && \
    wget -q "https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-linux-${PROTOC_ARCH}.zip" \
        -O /tmp/protoc.zip && \
    sudo unzip -q /tmp/protoc.zip -d /usr/local && \
    sudo chmod +x /usr/local/bin/protoc && \
    rm /tmp/protoc.zip && \
    protoc --version

########################################################################################
# Android SDK — JDK 17, cmdline-tools, platform-tools, build-tools, SDK platform
# Provides: adb, logcat, sdkmanager, aapt2, apksigner, javac/java
# Only installed on amd64 (Google's cmdline-tools zip is Linux x86_64 only).
########################################################################################
RUN if [ "$(dpkg --print-architecture)" = "amd64" ]; then \
    sudo apt-get -y update && \
    sudo apt-get -y install --no-install-recommends openjdk-17-jdk && \
    sudo apt-get -y clean && sudo apt-get -y autoremove && \
    sudo mkdir -p /opt/android-sdk && \
    sudo chown ${USERNAME}:${USERNAME} /opt/android-sdk && \
    wget -q "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip" \
        -O /tmp/cmdline-tools.zip && \
    unzip -q /tmp/cmdline-tools.zip -d /tmp/android-cmdline && \
    mkdir -p /opt/android-sdk/cmdline-tools && \
    mv /tmp/android-cmdline/cmdline-tools /opt/android-sdk/cmdline-tools/latest && \
    rm -rf /tmp/cmdline-tools.zip /tmp/android-cmdline && \
    yes | /opt/android-sdk/cmdline-tools/latest/bin/sdkmanager --licenses > /dev/null && \
    /opt/android-sdk/cmdline-tools/latest/bin/sdkmanager \
        "platform-tools" \
        "build-tools;${ANDROID_BUILD_TOOLS_VERSION}" \
        "platforms;android-${ANDROID_PLATFORM_VERSION}"; \
fi

########################################################################################
# fixuid — remaps container UID/GID at runtime to match the host user.
# Lets anyone docker pull + run --user $(id -u):$(id -g) without permission issues.
# https://github.com/boxboat/fixuid
########################################################################################
RUN case $(dpkg --print-architecture) in \
        amd64) FIXUID_ARCH="amd64" ;; \
        arm64) FIXUID_ARCH="arm64" ;; \
    esac && \
    wget -q "https://github.com/boxboat/fixuid/releases/download/v${FIXUID_VERSION}/fixuid-${FIXUID_VERSION}-linux-${FIXUID_ARCH}.tar.gz" \
        -O /tmp/fixuid.tar.gz && \
    sudo tar -C /usr/local/bin -xzf /tmp/fixuid.tar.gz && \
    sudo chown root:root /usr/local/bin/fixuid && \
    sudo chmod 4755 /usr/local/bin/fixuid && \
    rm /tmp/fixuid.tar.gz && \
    sudo mkdir -p /etc/fixuid && \
    printf "user: ${USERNAME}\ngroup: ${USERNAME}\npaths:\n  - /home/${USERNAME}\n  - /workdir\n" \
        | sudo tee /etc/fixuid/config.yml > /dev/null

########################################################################################
# OCI labels — lets `docker inspect` reveal exactly which tool versions are
# baked into any given image, independent of what the image tag says.
# (The image tag / NCS revision are versioned independently — see CHANGELOG.md.)
########################################################################################
LABEL org.opencontainers.image.title="illysky vanilla Zephyr build image" \
      org.opencontainers.image.source="https://github.com/illysky/zephyr-docker" \
      com.illysky.zephyr-sdk-version="${ZEPHYR_TOOLCHAIN_VERSION}" \
      com.illysky.west-version="${WEST_VERSION}" \
      com.illysky.jlink-version="${JLINK_VERSION}" \
      com.illysky.linkserver-version="${LINKSERVER_VERSION}" \
      com.illysky.go-version="${GO_VERSION}" \
      com.illysky.tio-version="${TIO_VERSION}"

########################################################################################
# Fetch upstream Zephyr (NOT NCS) and install its Python/west dependencies
########################################################################################
FROM base
ARG zephyr_revision=main
# IMAGE_VERSION is the full image tag (e.g. v4.4.1-b1), passed in by
# build_image.sh / CI. Independent of zephyr_revision — see CHANGELOG.md.
ARG IMAGE_VERSION=dev
LABEL org.opencontainers.image.version="${IMAGE_VERSION}" \
      com.illysky.zephyr-revision="${zephyr_revision}"
RUN \
    west init -m https://github.com/zephyrproject-rtos/zephyr --mr ${zephyr_revision} && \
    #west update --narrow -o=--depth=1 && \
    west update && \
    echo "Installing requirements: zephyr/scripts/requirements.txt" && \
    python3 -m pip install --break-system-packages -r zephyr/scripts/requirements.txt && \
    echo "Installing requirements: bootloader/mcuboot/scripts/requirements.txt" && \
    python3 -m pip install --break-system-packages -r bootloader/mcuboot/scripts/requirements.txt

########################################################################################
# Cadence/IntegrIT NatureDSP Signal libs (foss-xtensa/ndsplib-hifi1, -hifi4) — pinned
# to the exact commits zephyr-examples/west.yml tracks, at the same workspace-relative
# path (modules/lib/ndsplib-*) west would put them at. Source-available (licensed for
# Cadence cores only), not GPL/Apache — fine to bake into this image since they're
# just source, no Cadence toolchain/license involved. Plain git fetch-by-SHA (not a
# west project) since these two are pinned by commit, not branch, and don't need to
# move when zephyr_revision does.
#
# NOTE: these SHAs are project-specific to zephyr-examples and will drift out of sync
# if that repo's west.yml re-pins them — re-run this block with updated SHAs when it does.
########################################################################################
ARG NDSPLIB_HIFI1_REV=1f73a50fc6399c642163de47785f537e162ac5d9
ARG NDSPLIB_HIFI4_REV=8ec7552f670456b46249ee30be96dc6003b1285f
RUN mkdir -p modules/lib && \
    for pair in "ndsplib-hifi1:${NDSPLIB_HIFI1_REV}" "ndsplib-hifi4:${NDSPLIB_HIFI4_REV}"; do \
        name="${pair%%:*}"; rev="${pair##*:}"; \
        echo "Fetching foss-xtensa/${name} @ ${rev}" && \
        git init -q "modules/lib/${name}" && \
        git -C "modules/lib/${name}" remote add origin "https://github.com/foss-xtensa/${name}" && \
        git -C "modules/lib/${name}" fetch --depth=1 origin "${rev}" && \
        git -C "modules/lib/${name}" checkout -q FETCH_HEAD; \
    done

########################################################################################
# Create ENVs and make a project directory
########################################################################################
RUN mkdir /workdir/project
WORKDIR /workdir/project
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8
ENV XDG_CACHE_HOME=/workdir/.cache
ENV ZEPHYR_TOOLCHAIN_VARIANT=zephyr
ENV ZEPHYR_SDK_INSTALL_DIR=/workdir/zephyr-sdk
ENV ZEPHYR_BASE=/workdir/zephyr
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV PATH="/home/${USERNAME}/go/bin:/usr/local/go/bin:/opt/SEGGER/JLink:/usr/local/LinkServer:${ZEPHYR_BASE}/scripts:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/build-tools/34.0.0:${PATH}"
########################################################################################
# Update GIT Line Endings
########################################################################################
RUN git config --global core.autocrlf true
########################################################################################
# fixuid entrypoint — remaps UID/GID at container startup to match the caller.
# Usage: docker run --user $(id -u):$(id -g) ghcr.io/illysky/zephyr-docker:<tag>
########################################################################################
ENTRYPOINT ["fixuid", "-q"]
CMD ["/bin/bash"]
