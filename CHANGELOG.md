# Changelog

Release history for `ghcr.io/illysky/nrfconnect-sdk`. Tags follow
**`<sdk_nrf_revision>-b<build_num>`** — see the "Versioning" section of
[readme.md](readme.md) for the scheme. The exact tool versions baked into
any image are always recoverable via `docker inspect` (OCI/`com.illysky.*`
labels), regardless of tag.

| Tag(s) | NCS revision | Zephyr SDK | nrfutil | JLink | Go | Notes |
|---|---|---|---|---|---|---|
| `v3.5.0-preview1-b1` | `v3.5.0-preview1` | 1.0.1 | 1.4.0-5515776 | V960 | 1.26.5 | First release with nRF93M1 DK board support (only in NCS `main`/`v3.5.0-preview1`, not yet in a stable release). Adopted the decoupled `<ncs>-bN` versioning scheme, OCI image labels, Ubuntu 24.04, Python 3.13, fixuid, Android SDK, protoc. |
| `v3.3.0` … `v3.3.4` (`latest`) | `v3.3.0` | 0.17.4 | 1.2.3-e0abdbe | V940 | 1.22.5 | CI pipeline fixes only (auth, caching, build args) — no content change across these five tags. |
| `v3.2.3` | `v3.2.3` (approx.) | 0.17.4 | 1.2.3-e0abdbe | V866 | 1.22.5 | Pre-CI manual release (`build_image.sh` + manual `docker push`). |
| `v3.2.2` | `v3.2.2` (approx.) | 0.17.4 | 1.2.3-e0abdbe | V866 | 1.22.5 | Pre-CI manual release. |

## Versioning scheme (adopted `v3.5.0-preview1-b1`)

Previously the image tag was assumed to mirror the NCS version 1:1, but tool
bumps (JLink, nrfutil, Zephyr SDK, ...) kept happening independently of NCS
upgrades, and the `v3.3.x` tags above show that drifting in practice - tags
kept incrementing due to CI fixes, not actual content changes.

Going forward:

- Tag = `<sdk_nrf_revision>-b<build_num>`.
- Bump `build_num` for tool/Dockerfile-only changes.
- Reset `build_num` to `1` when `sdk_nrf_revision` changes.
- `latest` and the floating `<sdk_nrf_revision>` tag always point at the
  newest build.
- Every image carries `com.illysky.*` OCI labels recording the exact
  Zephyr SDK / west / JLink / nrfutil / Go / tio versions and NCS revision
  baked in, so the tag itself never needs to be the source of truth.
