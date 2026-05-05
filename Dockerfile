FROM ubuntu:22.04 AS base

########################################################################################
# Create a non-root user for this images. This can be overridden by build arguements, 
# and idealy mirror the host to avoid file and folder permission issues.
########################################################################################
ARG USERNAME=development
ARG USER_UID=1000
ARG USER_GID=$USER_UID
ARG ZEPHYR_TOOLCHAIN_VERSION=0.17.4
ARG WEST_VERSION=1.5.0
ARG JLINK_VERSION=V940
ARG NRFUTIL_VERSION=1.2.3-e0abdbe
ARG GO_VERSION=1.22.5
ARG TIO_VERSION=v3.9
########################################################################################
# See https://files.nordicsemi.com/ui/native/swtools/external/nrfutil/executables/x86_64-unknown-linux-gnu/ 
# For the latest (you have to use the hash)
########################################################################################

ARG arch=amd64
ARG crossarch=arm-zephyr-eabi
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
RUN groupadd --gid $USER_GID $USERNAME && \
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
        ninja-build \
        gperf \
        git \
        unzip \
        gn \
        libncurses5 libncurses5-dev \
        libyaml-dev libfdt1 \
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
RUN python3 -m pip install -U pip && \
    python3 -m pip install -U pipx && \
    python3 -m pip install uv && \
    python3 -m pip install -U setuptools && \
    python3 -m pip install 'cmake>=3.20.0' wheel && \
    python3 -m pip install -U "west==${WEST_VERSION}" && \
    python3 -m pip install pc_ble_driver_py && \
    # Newer PIP will not overwrite distutils, so upgrade PyYAML manually
    python3 -m pip install --ignore-installed -U PyYAML && \
    ########################################################################################
    # Enable Clang Support
    ########################################################################################
    python3 -m pip install -U six && \
    sudo apt-get -y install clang-format && \
    sudo apt-get -y install libsm6 && \
    wget -qO- https://raw.githubusercontent.com/nrfconnect/sdk-nrf/main/.clang-format > /workdir/.clang-format && \
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
    # Install nrfutil (official method from Nordic)
    ########################################################################################
    wget -O ~/.local/bin/nrfutil "https://files.nordicsemi.com/ui/api/v1/download?repoKey=swtools&path=external/nrfutil/executables/x86_64-unknown-linux-gnu/nrfutil-x86_64-unknown-linux-gnu-${NRFUTIL_VERSION}&isNativeBrowsing=false" && \
    chmod +x ~/.local/bin/nrfutil && \
    nrfutil install device && \
    nrfutil install nrf5sdk-tools && \
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
    case $ZEPHYR_TOOLCHAIN_ARCHIVE_FORMAT in \
        "gz") \
            wget -qO - "${ZEPHYR_MINIMAL_BUNDLE_URL}" | tar xz;; \
        *) \
            wget -qO - "${ZEPHYR_MINIMAL_BUNDLE_URL}" | tar xJ;; \
    esac && \
    mv /workdir/zephyr-sdk-${ZEPHYR_TOOLCHAIN_VERSION} /workdir/zephyr-sdk && cd /workdir/zephyr-sdk && \
    case $arch in \
        "arm64") \
            ./setup.sh -t aarch64-zephyr-elf -c \
            ;; \
        *) \
            yes | ./setup.sh -t ${crossarch} \
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
# Download sdk-nrf and west dependencies to install pip requirements
########################################################################################
FROM base
ARG sdk_nrf_revision=main   
ARG sdk_nrf_commit
RUN \
    #west init -m https://github.com/krish2718/sdk-nrf --mr ${sdk_nrf_revision} && \
    west init -m https://github.com/nrfconnect/sdk-nrf --mr ${sdk_nrf_revision} && \
    if [[ $sdk_nrf_commit =~ "^[a-fA-F0-9]{32}$" ]]; then \
        git checkout ${sdk_nrf_revision} ; \
    fi && \
    #west update --narrow -o=--depth=1 && \
    west update && \
    echo "Installing requirements: zephyr/scripts/requirements.txt" && \
    python3 -m pip install -r zephyr/scripts/requirements.txt && \
    # Install only the requirements needed for building firmware, not documentation
    echo "Installing requirements: nrf/scripts/requirements-base.txt" && \
    python3 -m pip install -r nrf/scripts/requirements-base.txt && \
    echo "Installing requirements: nrf/scripts/requirements-build.txt" && \
    python3 -m pip install -r nrf/scripts/requirements-build.txt && \
    echo "Installing requirements: bootloader/mcuboot/scripts/requirements.txt" && \
    python3 -m pip install -r bootloader/mcuboot/scripts/requirements.txt

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
ENV PATH="/home/${USERNAME}/.nrfutil/bin:/home/${USERNAME}/go/bin:/usr/local/go/bin:/opt/SEGGER/JLink:${ZEPHYR_BASE}/scripts:${PATH}"
########################################################################################
# Update GIT Line Endings
########################################################################################
RUN git config --global core.autocrlf true
########################################################################################
# We will start as USER
########################################################################################
