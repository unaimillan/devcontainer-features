
# OSS CAD Suite (shared volume) (oss-cad-suite)

YosysHQ oss-cad-suite (yosys, nextpnr, verilator, iverilog, ...) downloaded once per Docker host into a shared named volume and reused by every dev container.

## Example Usage

```json
"features": {
    "ghcr.io/unaimillan/devcontainer-features/oss-cad-suite:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | oss-cad-suite release tag (YYYY-MM-DD). 'latest' is resolved to a concrete tag at image build time; pin a date tag for reproducible builds. | string | latest |

## How it works

[YosysHQ oss-cad-suite](https://github.com/YosysHQ/oss-cad-suite-build) is a ~700 MiB
download (~2.4 GB unpacked). This feature downloads each release **only once per Docker
host**, so a new dev container doesn't have to fetch it again.

- The feature mounts the named Docker volume `oss-cad-suite` at `/opt/oss-cad-suite`.
  Every dev container on the same Docker host that uses this feature shares that volume.
- Each release goes in its own subfolder (`/opt/oss-cad-suite/<tag>/`), so projects
  pinned to different versions can live side by side.
- At image build time, `install.sh`:
  - resolves `latest` to a concrete tag
  - makes `/usr/local/oss-cad-suite` a symlink to `/opt/oss-cad-suite/<tag>`
  - makes the volume root world-writable with the sticky bit (`1777`, like `/tmp`), so
    containers with different remote users can share it. The feature's `entrypoint` (run as
    root) re-applies this on Docker setups that create new volumes root-owned
  - installs the prerequisites (`curl`, `perl`, `make`, `g++`, ...)
- On container create (`onCreateCommand`), `ensure.sh` downloads the release if it isn't
  in the volume yet. A `flock` keeps containers created at the same time from both
  downloading; the lock is held on the volume directory itself, so no lock file is left behind
  with the wrong owner. If the release is already there, it finishes immediately.
- `/usr/local/oss-cad-suite/bin` is **appended** to `PATH`, so system and project tools
  keep priority. The suite's bundled Python (`py3bin/`) is left off `PATH`. To get the
  suite's full environment, run `source /usr/local/oss-cad-suite/environment`.

## Version pinning

`version` is an oss-cad-suite release tag (`YYYY-MM-DD`, daily builds). To find the
latest tag:

```sh
curl -fsSL https://api.github.com/repos/YosysHQ/oss-cad-suite-build/releases/latest | grep -oP '"tag_name":\s*"\K[^"]+'
```

## Maintenance

```sh
docker run --rm -v oss-cad-suite:/v alpine ls -la /v            # list cached versions
docker run --rm -v oss-cad-suite:/v alpine rm -rf /v/<old-tag>  # drop one version
docker volume rm oss-cad-suite                                  # drop everything
```

## OS support

Debian/Ubuntu-based images (`apt-get`), on `x86_64` or `aarch64`.


---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/unaimillan/devcontainer-features/blob/main/src/oss-cad-suite/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
