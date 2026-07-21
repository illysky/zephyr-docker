# NCS Docker Build Environment

A Docker image containing all dependencies needed to build firmware with the [Nordic Connect SDK (NCS)](https://developer.nordicsemi.com/nRF_Connect_SDK/doc/latest/nrf/index.html) and Zephyr RTOS. Designed for reproducible, host-independent builds and works as both a standalone build container and a VS Code / Cursor Dev Container.

## What's included

| Tool | Version | Purpose |
|---|---|---|
| Ubuntu | 24.04 | Base OS |
| NCS / Zephyr | configurable | Firmware SDK (`west init` on build) |
| Zephyr SDK (toolchain) | 1.0.1 | ARM cross-compiler (`arm-zephyr-eabi`) |
| west | 1.5.0 | Zephyr meta-tool / build system |
| SEGGER JLink | V960 | JLink flash/debug support |
| nrfutil | 1.4.0 | Nordic flashing and device tools |
| pyocd | latest (pip) | CMSIS-DAP flash/debug (e.g. XIAO nRF54L15) |
| openocd | system | Open On-Chip Debugger |
| Go | 1.26.5 | Required for mcumgr |
| mcumgr | latest | Zephyr device management (DFU over serial/BLE) |
| tio | v3.9 | Serial terminal (built from source) |
| protoc | 33.2 | Protocol Buffers compiler |
| Android SDK | platform 34 | adb/logcat/sdkmanager (amd64 only) |
| Python tools | latest | west, cmake, PyYAML, pc_ble_driver_py, etc. |

The image mirrors your host user (UID/GID) so built files have correct permissions without needing root (via `fixuid`, remapped at container startup).

## Versioning

Image tags follow **`<sdk_nrf_revision>-b<build_num>`**, e.g. `v3.5.0-preview1-b1`.
The tag is *decoupled* from the NCS revision baked into the image:

- Bump `build_num` when only tools/Dockerfile change (NCS pin unchanged).
- Reset `build_num` to `1` whenever `sdk_nrf_revision` changes.

Every build/push also updates two floating tags:

- `latest` — always the newest build, regardless of NCS revision.
- `<sdk_nrf_revision>` (no `-bN` suffix) — the newest build for that specific
  NCS revision, for consumers who just want current tools without caring
  about the build counter.

The exact tool versions and NCS revision baked into **any** image (regardless
of which tag you pulled it by) are recorded as OCI/custom labels — inspect
with:

```bash
docker inspect ghcr.io/illysky/nrfconnect-sdk:<tag> --format '{{json .Config.Labels}}' | python3 -m json.tool
```

See [CHANGELOG.md](CHANGELOG.md) for the release history.

## Building the image

```bash
# Build for NCS v3.5.0-preview1, build 1 (defaults)
./build_image.sh

# Build for a specific NCS revision + build number
./build_image.sh v3.4.0 2

# Build and push both the compound tag and the floating <sdk_nrf_revision> alias
./build_image.sh v3.5.0-preview1 1 --push
```

This produces a Docker image tagged `nrfconnect-sdk:<sdk_nrf_revision>-b<build_num>`
(and, when pushing, `ghcr.io/illysky/nrfconnect-sdk:<sdk_nrf_revision>-b<build_num>`
+ the floating `ghcr.io/illysky/nrfconnect-sdk:<sdk_nrf_revision>` alias).

### Build arguments

| Argument | Default | Description |
|---|---|---|
| `sdk_nrf_revision` | `main` | NCS branch/tag to fetch |
| `IMAGE_VERSION` | `dev` | Full image tag, recorded as an OCI label (set automatically by `build_image.sh`/CI) |
| `ZEPHYR_TOOLCHAIN_VERSION` | `1.0.1` | Zephyr SDK release |
| `WEST_VERSION` | `1.5.0` | west pip version |
| `JLINK_VERSION` | `V960` | SEGGER JLink release |
| `NRFUTIL_VERSION` | `1.4.0-5515776` | Nordic nrfutil release |
| `GO_VERSION` | `1.26.5` | Go toolchain version |
| `TIO_VERSION` | `v3.9` | tio release tag |
| `USER_UID` / `USER_GID` | `1000` | Mirror host user (set automatically by `build_image.sh`) |

## Usage

### Dev Container (VS Code / Cursor) — recommended

Create `.devcontainer/devcontainer.json` in your project root:

```json
{
    "name": "nrfconnect-sdk",
    "image": "ghcr.io/illysky/nrfconnect-sdk:v3.5.0-preview1",
    "runArgs": [
        "--privileged",
        "--net=host",
        "-u", "${localEnv:USER}"
    ],
    "customizations": {
        "vscode": {
            "extensions": [
                "nordic-semiconductor.nrf-connect-extension-pack",
                "nordic-semiconductor.nrf-devicetree",
                "nordic-semiconductor.nrf-kconfig",
                "mcu-debug.debug-tracker-vscode",
                "ms-vscode.cpptools"
            ]
        }
    }
}
```

`--privileged` is required for USB access (JLink, CMSIS-DAP, serial ports).

### Standalone build

```bash
docker run --rm \
    -v $(pwd):/workdir/project \
    -u $(id -u):$(id -g) \
    ghcr.io/illysky/nrfconnect-sdk:v3.5.0-preview1 \
    west build -b <board> <app>
```

### Interactive shell

```bash
docker run --rm -it \
    --privileged \
    --net=host \
    -v $(pwd):/workdir/project \
    -u $(id -u):$(id -g) \
    ghcr.io/illysky/nrfconnect-sdk:v3.5.0-preview1 \
    bash
```

## Flashing

Inside the container, use whichever runner matches your hardware:

```bash
# JLink (nRF52/nRF53/nRF91 dev kits)
west flash --runner jlink

# CMSIS-DAP via pyocd (e.g. Seeed XIAO nRF54L15)
west flash --runner pyocd --dev-id <probe-uid>

# nrfutil (USB DFU)
west flash --runner nrfutil
```

Serial monitor with tio:

```bash
tio /dev/ttyACM0
```

mcumgr DFU over serial:

```bash
mcumgr --conntype serial --connstring /dev/ttyACM0,baud=115200 image upload build/zephyr/app_update.bin
```
