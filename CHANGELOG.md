# Changelog

Release history for `ghcr.io/illysky/zephyr-docker`. Tags follow
**`<zephyr_revision>-b<build_num>`** — see the "Versioning" section of
[readme.md](readme.md) for the scheme. The exact tool versions baked into
any image are always recoverable via `docker inspect` (OCI/`com.illysky.*`
labels), regardless of tag.

| Tag(s) | Zephyr revision | Zephyr SDK | JLink | LinkServer | Go | Notes |
|---|---|---|---|---|---|---|
| `v4.4.1-b1` | `v4.4.1` | 1.0.1 | V960 | 26.5.59 | 1.26.5 | Initial release. Forked from [`illysky/ncs-docker`](https://github.com/illysky/ncs-docker) `v3.5.0-preview1-b1`: swapped the NCS/`sdk-nrf` west manifest for upstream `zephyrproject-rtos/zephyr`, dropped Nordic-only tooling (`nrfutil`), and added NXP LinkServer + the bundled MCU-LINK_installer (`program_CMSIS`/`program_JLINK`) plus MCU-Link/CMSIS-DAP udev rules for onboard debug probes like the one on the MIMXRT700-EVK. Repo made public and the GHCR package kept public so the image can be pulled without auth. |

## Versioning scheme

- Tag = `<zephyr_revision>-b<build_num>`.
- Bump `build_num` for tool/Dockerfile-only changes.
- Reset `build_num` to `1` when `zephyr_revision` changes.
- `latest` and the floating `<zephyr_revision>` tag always point at the
  newest build.
- Every image carries `com.illysky.*` OCI labels recording the exact
  Zephyr SDK / west / JLink / LinkServer / Go / tio versions and Zephyr
  revision baked in, so the tag itself never needs to be the source of truth.
