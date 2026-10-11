# Dev Container Features

Custom [dev container Features](https://containers.dev/implementors/features/), published to
GitHub Container Registry under `ghcr.io/unaimillan/devcontainer-features`.

| Feature | Description |
|---|---|
| [`oss-cad-suite`](src/oss-cad-suite) | [YosysHQ oss-cad-suite](https://github.com/YosysHQ/oss-cad-suite-build) (yosys, nextpnr, verilator, iverilog, ...), downloaded once per Docker host into a shared named volume and reused by every dev container. |

## `oss-cad-suite`

```jsonc
{
    "image": "mcr.microsoft.com/devcontainers/base:bookworm",
    "features": {
        // Pin a release date for reproducible builds; omit "version" (or use "latest")
        // to resolve the newest release when the image is built.
        "ghcr.io/unaimillan/devcontainer-features/oss-cad-suite:1": {
            "version": "2026-10-11"
        }
    }
}
```

```console
$ yosys -V && verilator --version
Yosys 0.69+274 (git sha1 7513f8df8, Release, Clang /usr/bin/clang++ 21.1.8)
Verilator 5.053 devel rev v5.052-362-ge9f8cb2d9 (mod)
```

The first container on a Docker host downloads the release (~700 MiB) into the
`oss-cad-suite` volume. After that, every container finds it there and skips the download.
See the [feature docs](src/oss-cad-suite) for how it works and how to clean up old versions.

## Repo layout

```
src/<feature>/      devcontainer-feature.json, install.sh, NOTES.md (+ generated README.md)
test/<feature>/     test.sh (default options) + scenarios.json and per-scenario scripts
```

Test locally with the [dev container CLI](https://github.com/devcontainers/cli):

```sh
devcontainer features test -f oss-cad-suite -i debian:latest .
```

## Publishing

- [`release.yaml`](.github/workflows/release.yaml) (manual `workflow_dispatch` on `main`)
  publishes every feature to GHCR. Each feature is versioned by the `version` field in its
  `devcontainer-feature.json` (semver; `1.0.0` is published as `:1`, `:1.0`, `:1.0.0` and
  `:latest`). Bump it on every change, or the release skips the feature.
- The workflow also opens a PR with regenerated `src/<feature>/README.md` files. For that
  to work, enable *Read and write permissions* and *Allow GitHub Actions to create and
  approve pull requests* under `Settings > Actions > General > Workflow permissions`.
- New GHCR packages are **private**. Make each one public in its package settings, e.g.
  `https://github.com/users/unaimillan/packages/container/devcontainer-features%2Foss-cad-suite/settings`.

## License

[MIT](LICENSE)
