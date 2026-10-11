## How it works

[Hermes Agent](https://github.com/NousResearch/hermes-agent) normally keeps its code, its tool
store and your data together in `~/.hermes`. If you persist that folder in a volume, the volume
hides every newer build, so rebuilding the container no longer updates Hermes. This feature
splits them up:

| What | Option (default) | Where it lives |
|---|---|---|
| Code checkout (installer `--dir`) | `installDir` (`/opt/hermes/agent`) | image, rebuilt fresh |
| Tool store (`HERMES_RUNTIME_DIR`: uv, node, ripgrep, ...) | `runtimeDir` (`/opt/hermes/tools`) | image, rebuilt fresh |
| Data (`HERMES_HOME`: `config.yaml`, `.env`, memories, sessions, skills, logs) | `homeDir` (`/var/lib/hermes`) | named volume `hermes-agent-config` |
| `~/.hermes` → `homeDir` symlink | `linkUserHome` (`true`) | image |

- **At image build time**, `install.sh` runs the upstream installer as the remote user with
  `--non-interactive`. The installer is downloaded from the same ref as the code it installs.
- **Commands:** `hermes`, `hermes-acp` and `hermes-agent` in `/usr/local/bin` (and `~/.local/bin`)
  are a small shim. It sets the `HERMES_*` defaults, so every caller gets the right paths, including
  tasks, `docker exec` and the gateway. Values you set yourself (for example in `containerEnv`) win.
  Login and interactive shells also get the defaults, through `/etc/profile.d/hermes-agent.sh` and
  `/etc/bash.bashrc`.
- **On container create**, `ensure.sh` makes sure `HERMES_HOME` is writable and holds the config
  skeleton. It never overwrites existing files. Run `hermes setup` once; the result stays in the volume.
- **On every start**, the feature's `entrypoint` (as root) hands the volume root to the remote user
  if Docker created it root-owned. That happens with the containerd image store, which doesn't seed
  new volumes from the image.
- `hermes update` works inside a running container on a branch install (see below). It updates the
  container's copy only; the next rebuild starts again from the image.

### The volume is shared

`hermes-agent-config` is one volume per Docker host. Every dev container that uses this feature
sees the same config, API keys, memories and sessions. Containers running at the same time write
to the same session store. If the containers run as different users, each start re-owns only the
volume root, not its contents. Remote users with the same uid (`vscode` and `node` are both 1000)
work without any change.

### Custom paths

A feature can't use option values in its `mounts` or `containerEnv`, so the volume is **always**
mounted at `/var/lib/hermes`. If you change `homeDir`, add your own mount for it, or its data is
lost on rebuild:

```jsonc
"features": {
    "ghcr.io/unaimillan/devcontainer-features/hermes-agent:1": { "homeDir": "/home/vscode/.hermes" }
},
"mounts": ["source=my-hermes,target=/home/vscode/.hermes,type=volume"]
```

The parent of `installDir` must not exist yet (it's created for the remote user) or must already be
writable by the remote user, because the installer stages its clone next to the checkout.

## Version pinning

| `version` | Installs | `hermes update` in a running container |
|---|---|---|
| `latest` (default) / `main` / another branch | that branch's HEAD at image build time | moves to the branch's newer commits |
| a commit SHA (must be on `main`) | that commit, detached | leaves it alone ("Already up to date") |

Either way, the installed commit is recorded in `/usr/local/share/hermes-agent/version`. Docker caches
the feature's layer, so `latest` only moves when the image is rebuilt without cache (or the feature
options change). To find the current HEAD:

```sh
git ls-remote https://github.com/NousResearch/hermes-agent refs/heads/main
```

## Optional components

`browser` (agent-browser + Chromium) and `computerUse` (cua-driver) are off by default, which passes
`--skip-browser` / `--skip-computer-use`. You can still add them later in a running container with
`hermes pm install agent-browser` or `hermes pm install cua-driver`.

## Maintenance

```sh
docker run --rm -v hermes-agent-config:/v alpine ls -la /v                          # inspect
docker run --rm -v hermes-agent-config:/v -v "$PWD":/b alpine tar czf /b/hermes.tgz -C /v .  # back up
docker volume rm hermes-agent-config                                                # drop everything
```

## Migrating from a manual install

If `devcontainer.json` installs Hermes by hand (`postCreateCommand` running `install.sh`, a
`hermes-agent-config` mount on `~/.hermes`, `HERMES_HOME`/`HERMES_RUNTIME_DIR` in `containerEnv`, and a
`chown` of the volume), remove all of that and add the feature. It mounts the same
`hermes-agent-config` volume, so the existing config, keys and providers are picked up as they are.

## OS support

Debian/Ubuntu-based images (`apt-get`), on `x86_64` or `aarch64`.
