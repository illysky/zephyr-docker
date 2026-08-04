# Changelog

Release history for `ghcr.io/illysky/zephyr-docker`. Tags follow
**`<zephyr_revision>-b<build_num>`** — see the "Versioning" section of
[readme.md](readme.md) for the scheme. The exact tool versions baked into
any image are always recoverable via `docker inspect` (OCI/`com.illysky.*`
labels), regardless of tag.

| Tag(s) | Zephyr revision | Zephyr SDK | JLink | LinkServer | Go | Notes |
|---|---|---|---|---|---|---|
| `v4.4.1-b2` | `v4.4.1` | 1.0.1 | V960 | 26.5.59 | 1.26.5 | Bakes in the Xtensa GNU toolchains for the MIMXRT700-EVK's DSP cores (`xtensa-nxp_rt700_hifi4_zephyr-elf`, `xtensa-nxp_rt700_hifi1_zephyr-elf`), installed alongside `arm-zephyr-eabi` via the new `extra_toolchains` build-arg. Without these, `west build` for `illysky/zephyr-examples`' `apps/rt700/all_four_cores` (and any other app targeting the hifi4/hifi1 sysbuild images) failed at CMake configure with "C compiler ... not found" — only the CM33 (ARM) cores could compile. |
| `v4.4.1-b1` | `v4.4.1` | 1.0.1 | V960 | 26.5.59 | 1.26.5 | Bakes in `foss-xtensa/ndsplib-hifi1` and `ndsplib-hifi4` (Cadence/IntegrIT NatureDSP source, pinned to the exact commits `illysky/zephyr-examples`' `west.yml` tracks) at `modules/lib/ndsplib-*`, plain-git fetched by SHA — not via `west`, since these two move independently of `zephyr_revision`. Source-only, no Cadence toolchain/license involved, so this doesn't affect the image's public distribution. Also switched CI to the `type=gha` Buildx cache backend (was `no-cache: true`) so unchanged layers — especially the large `base` stage — aren't rebuilt from scratch on every push. NOTE: these SHAs are project-specific and will drift if `zephyr-examples/west.yml` re-pins them. |
| `v4.4.1` | `v4.4.1` | 1.0.1 | V960 | 26.5.59 | 1.26.5 | Initial release. Forked from [`illysky/ncs-docker`](https://github.com/illysky/ncs-docker) `v3.5.0-preview1-b1`: swapped the NCS/`sdk-nrf` west manifest for upstream `zephyrproject-rtos/zephyr`, dropped Nordic-only tooling (`nrfutil`), and added NXP LinkServer + the bundled MCU-LINK_installer (`program_CMSIS`/`program_JLINK`) plus MCU-Link/CMSIS-DAP udev rules for onboard debug probes like the one on the MIMXRT700-EVK. Repo made public; GHCR package visibility flipped to public manually one-time (no API for this on org packages — see readme). |

## Versioning scheme

- Tag = `<zephyr_revision>-b<build_num>`.
- Bump `build_num` for tool/Dockerfile-only changes.
- Reset `build_num` to `1` when `zephyr_revision` changes.
- `latest` and the floating `<zephyr_revision>` tag always point at the
  newest build.
- Every image carries `com.illysky.*` OCI labels recording the exact
  Zephyr SDK / west / JLink / LinkServer / Go / tio versions and Zephyr
  revision baked in, so the tag itself never needs to be the source of truth.
