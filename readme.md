# Zephyr Docker Build Environment

A Docker image containing all dependencies needed to build firmware with
**vanilla upstream [Zephyr RTOS](https://docs.zephyrproject.org/)** (no
Nordic Connect SDK) — see [`illysky/ncs-docker`](https://github.com/illysky/ncs-docker)
for the NCS equivalent this was forked from. Designed for reproducible,
host-independent builds and works as both a standalone build container and a
VS Code / Cursor Dev Container.

## What's included

| Tool | Version | Purpose |
|---|---|---|
| Ubuntu | 24.04 | Base OS |
| Zephyr | configurable | Firmware SDK (`west init -m zephyrproject-rtos/zephyr` on build) |
| Zephyr SDK (toolchain) | 1.0.1 | ARM cross-compiler (`arm-zephyr-eabi`) |
| west | 1.5.0 | Zephyr meta-tool / build system |
| SEGGER JLink | V960 | JLink flash/debug support |
| NXP LinkServer | 26.5.59 | MCU-Link CMSIS-DAP/J-Link debug host tools + firmware switch scripts (`program_CMSIS`/`program_JLINK`) |
| openocd | system | Open On-Chip Debugger |
| Go | 1.26.5 | Required for mcumgr |
| mcumgr | latest | Zephyr device management (DFU over serial/BLE) |
| tio | v3.9 | Serial terminal (built from source) |
| protoc | 33.2 | Protocol Buffers compiler |
| Android SDK | platform 34 | adb/logcat/sdkmanager (amd64 only) |
| Python tools | latest | west, cmake, PyYAML, etc. |

The image mirrors your host user (UID/GID) so built files have correct permissions without needing root (via `fixuid`, remapped at container startup).

### MCU-Link / NXP debug probes

LinkServer is installed at `/usr/local/LinkServer` (on `$PATH`), and its
bundled `MCU-LINK_installer` (with `program_CMSIS`/`program_JLINK`) lands at
`/usr/local/MCU-LINK_installer_<ver>/scripts/`. Use these to flash an onboard
MCU-Link probe (e.g. on a MIMXRT700-EVK) with either CMSIS-DAP or SEGGER
J-Link firmware — see the
[MCU-Link Debug Probe Architecture](https://www.nxp.com/design/design-center/software/development-software/mcu-link-debug-probe-architecture:MCU-LINK-ARCHITECTURE)
page for firmware/probe compatibility.

A udev rules file for NXP CMSIS-DAP probes (normal + ISP/DFU-mode PIDs) is
baked in at `/etc/udev/rules.d/60-nxp-debug-probes.rules`, for reference / in
case you need the equivalent rule on the **host** (udev rules only apply on
the host — see [Flashing](#flashing) below for why `--privileged` is used).

## Versioning

Image tags follow **`<zephyr_revision>-b<build_num>`**, e.g. `v4.4.1-b1`.
The tag is *decoupled* from the Zephyr revision baked into the image:

- Bump `build_num` when only tools/Dockerfile change (Zephyr pin unchanged).
- Reset `build_num` to `1` whenever `zephyr_revision` changes.

Every build/push also updates two floating tags:

- `latest` — always the newest build, regardless of Zephyr revision.
- `<zephyr_revision>` (no `-bN` suffix) — the newest build for that specific
  Zephyr revision, for consumers who just want current tools without caring
  about the build counter.

The exact tool versions and Zephyr revision baked into **any** image
(regardless of which tag you pulled it by) are recorded as OCI/custom
labels — inspect with:

```bash
docker inspect ghcr.io/illysky/zephyr-docker:<tag> --format '{{json .Config.Labels}}' | python3 -m json.tool
```

See [CHANGELOG.md](CHANGELOG.md) for the release history.

## Building the image

```bash
# Build for Zephyr v4.4.1, build 1 (defaults)
./build_image.sh

# Build and push a specific Zephyr revision + build number
./build_image.sh v4.4.1 1 --push

# Track a moving branch instead of a tagged release
./build_image.sh main 1 --push
```

This produces a Docker image tagged `zephyr-docker:<zephyr_revision>-b<build_num>`
(and, when pushing, `ghcr.io/illysky/zephyr-docker:<zephyr_revision>-b<build_num>`
+ the floating `ghcr.io/illysky/zephyr-docker:<zephyr_revision>` alias).

### Build arguments

| Argument | Default | Description |
|---|---|---|
| `zephyr_revision` | `main` | Zephyr branch/tag/SHA to fetch |
| `IMAGE_VERSION` | `dev` | Full image tag, recorded as an OCI label (set automatically by `build_image.sh`/CI) |
| `ZEPHYR_TOOLCHAIN_VERSION` | `1.0.1` | Zephyr SDK release |
| `WEST_VERSION` | `1.5.0` | west pip version |
| `JLINK_VERSION` | `V960` | SEGGER JLink release |
| `LINKSERVER_VERSION` | `26.5.59` | NXP LinkServer release |
| `GO_VERSION` | `1.26.5` | Go toolchain version |
| `TIO_VERSION` | `v3.9` | tio release tag |
| `USER_UID` / `USER_GID` | `1000` | Mirror host user (set automatically by `build_image.sh`) |

## Usage

### Dev Container (VS Code / Cursor) — recommended

Create `.devcontainer/devcontainer.json` in your project root:

```json
{
    "name": "zephyr",
    "image": "ghcr.io/illysky/zephyr-docker:v4.4.1",
    "runArgs": [
        "--privileged",
        "--net=host",
        "-u", "${localEnv:USER}"
    ],
    "customizations": {
        "vscode": {
            "extensions": [
                "mcu-debug.debug-tracker-vscode",
                "ms-vscode.cpptools"
            ]
        }
    }
}
```

`--privileged` is required for USB access (JLink, CMSIS-DAP/MCU-Link, serial ports).

### Standalone build

```bash
docker run --rm \
    -v $(pwd):/workdir/project \
    -u $(id -u):$(id -g) \
    ghcr.io/illysky/zephyr-docker:v4.4.1 \
    west build -b <board> <app>
```

### Interactive shell

```bash
docker run --rm -it \
    --privileged \
    --net=host \
    -v $(pwd):/workdir/project \
    -u $(id -u):$(id -g) \
    ghcr.io/illysky/zephyr-docker:v4.4.1 \
    bash
```

## Flashing

Inside the container, use whichever runner matches your hardware:

```bash
# JLink
west flash --runner jlink

# NXP LinkServer (MCU-Link CMSIS-DAP or J-Link firmware, e.g. MIMXRT700-EVK)
west flash --runner linkserver

# CMSIS-DAP via pyocd / openocd
west flash --runner openocd
```

Serial monitor with tio:

```bash
tio /dev/ttyACM0
```

mcumgr DFU over serial:

```bash
mcumgr --conntype serial --connstring /dev/ttyACM0,baud=115200 image upload build/zephyr/zephyr.signed.bin
```

## Pulling without authentication

This image is published publicly to GHCR — `docker pull ghcr.io/illysky/zephyr-docker:latest`
works with no `docker login` required. The CI workflow re-asserts the
package's public visibility on every run.
