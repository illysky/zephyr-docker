# NCS Docker Build Environment

A Docker image containing all dependencies needed to build firmware with the [Nordic Connect SDK (NCS)](https://developer.nordicsemi.com/nRF_Connect_SDK/doc/latest/nrf/index.html) and Zephyr RTOS. Designed for reproducible, host-independent builds and works as both a standalone build container and a VS Code / Cursor Dev Container.

## What's included

| Tool | Version | Purpose |
|---|---|---|
| Ubuntu | 22.04 | Base OS |
| NCS / Zephyr | configurable | Firmware SDK (`west init` on build) |
| Zephyr SDK (toolchain) | 0.17.4 | ARM cross-compiler (`arm-zephyr-eabi`) |
| west | 1.5.0 | Zephyr meta-tool / build system |
| SEGGER JLink | V866 | JLink flash/debug support |
| nrfutil | 1.2.3 | Nordic flashing and device tools |
| pyocd | latest (pip) | CMSIS-DAP flash/debug (e.g. XIAO nRF54L15) |
| openocd | system | Open On-Chip Debugger |
| Go | 1.22.5 | Required for mcumgr |
| mcumgr | latest | Zephyr device management (DFU over serial/BLE) |
| tio | v3.9 | Serial terminal (built from source) |
| Python tools | latest | west, cmake, PyYAML, pc_ble_driver_py, etc. |

The image mirrors your host user (UID/GID) so built files have correct permissions without needing root.

## Building the image

```bash
# Build for NCS v3.1.1 (default)
./build_image.sh

# Build for a specific NCS version
./build_image.sh v2.9.0
```

This produces a Docker image tagged `nrfconnect-sdk:<version>`.

### Build arguments

| Argument | Default | Description |
|---|---|---|
| `sdk_nrf_revision` | `main` | NCS branch/tag to fetch |
| `ZEPHYR_TOOLCHAIN_VERSION` | `0.17.4` | Zephyr SDK release |
| `WEST_VERSION` | `1.5.0` | west pip version |
| `JLINK_VERSION` | `V866` | SEGGER JLink release |
| `GO_VERSION` | `1.22.5` | Go toolchain version |
| `TIO_VERSION` | `v3.9` | tio release tag |
| `USER_UID` / `USER_GID` | `1000` | Mirror host user (set automatically by `build_image.sh`) |

## Usage

### Dev Container (VS Code / Cursor) — recommended

Create `.devcontainer/devcontainer.json` in your project root:

```json
{
    "name": "nrfconnect-sdk",
    "image": "nrfconnect-sdk:v3.1.1",
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
    nrfconnect-sdk:v3.1.1 \
    west build -b <board> <app>
```

### Interactive shell

```bash
docker run --rm -it \
    --privileged \
    --net=host \
    -v $(pwd):/workdir/project \
    -u $(id -u):$(id -g) \
    nrfconnect-sdk:v3.1.1 \
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
