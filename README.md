# rtk-nix

Unofficial Nix packaging for [rtk](https://github.com/rtk-ai/rtk) (Rust Token Killer), fetched
from upstream GitHub Releases (no from-source build)

> **Name collision:** this packages `rtk-ai/rtk` — the CLI proxy that reduces LLM token
> consumption, the one with `rtk gain`. It is *not* `reachingforthejack/rtk` (Rust Type Kit),
> a different project that shares the binary name.

## Contents

- [Why this exists](#why-this-exists)
- [Usage](#usage)
- [Configuration / API](#configuration--api)
- [Staying current](#staying-current)
- [Contributing](#contributing)
- [Provenance and handover intent](#provenance-and-handover-intent)
- [Licensing](#licensing)

## Why this exists

rtk ships no Nix packaging of its own. Its [documented install
paths](https://github.com/rtk-ai/rtk/blob/master/INSTALL.md) are `curl … install.sh | sh`
(which drops a binary outside the store), `cargo install --git` (which builds from source,
pulling in the full Rust toolchain, on every install and every update), or distro `.deb`/`.rpm`
packages. None of those fit a declarative Nix or devenv setup, and the source build repeats for
every consumer, every time — especially unwelcome in a devenv context, where the shell can
rebuild often.

This repo instead fetches rtk's own prebuilt, per-platform release tarballs
(`rtk-x86_64-unknown-linux-musl`, `rtk-aarch64-unknown-linux-gnu`, `rtk-x86_64-apple-darwin`,
`rtk-aarch64-apple-darwin` — published on every tagged stable release) and wraps them in a Nix
derivation. No compilation, no toolchain, just a hash-verified download.

Built binaries are pushed to a Cachix cache (`rtk`) so downstream consumers never build locally
at all — `nix build`/`devenv shell` just pulls the substitute. Pushing happens continuously from
two workflows: every `ci.yml` run on `main`/PRs, and the daily `update-check.yml` run — so a
newly detected rtk release is already cached before its version-bump PR is even reviewed.

## Usage

### With devenv

Add the flake input and pull the `rtk` Cachix cache declaratively — devenv wires the
substituter and trusted public key for you, no manual `nix.conf` editing:

```yaml
# devenv.yaml
inputs:
  rtk-nix:
    url: github:tburny/rtk-nix
```

```nix
# devenv.nix
{ pkgs, inputs, ... }:

{
  cachix.pull = [ "rtk" ];

  packages = [
    inputs.rtk-nix.packages.${pkgs.stdenv.system}.default
  ];
}
```

`devenv shell` then pulls `rtk` straight from the cache instead of building it.

### Standalone Nix (flakes)

```nix
{
  inputs.rtk-nix.url = "github:tburny/rtk-nix";
  # ...
  # inputs.rtk-nix.packages.${system}.default
}
```

Or run it directly without adding an input:

```sh
nix run github:tburny/rtk-nix
```

To pull from the cache instead of building, add the substituter to your user/system
`nix.conf` (or `~/.config/nix/nix.conf`):

```
extra-substituters = https://rtk.cachix.org
extra-trusted-public-keys = rtk.cachix.org-1:YXdWe1jb6i0KAPXwHFT71ALd04lMkMVFNjpY6vKcSbM=
```

Or, if you're consuming this as a flake input and have `accept-flake-config = true` set
(or answer `y` to the one-time prompt), declare it in your own `flake.nix` instead so
consumers of *your* flake pick it up too:

```nix
{
  nixConfig = {
    extra-substituters = [ "https://rtk.cachix.org" ];
    extra-trusted-public-keys = [ "rtk.cachix.org-1:YXdWe1jb6i0KAPXwHFT71ALd04lMkMVFNjpY6vKcSbM=" ];
  };
}
```

To verify that key against the cache itself, run `cachix use rtk`, or read it
straight from the API: `curl -s https://cachix.org/api/v1/cache/rtk`.

## Configuration / API

This is a plain package flake — no NixOS/devenv module options, nothing to configure beyond
picking a system. It exposes:

| Output | Type | Notes |
|---|---|---|
| `packages.<system>.rtk` | derivation | The rtk binary, installed at `bin/rtk`. |
| `packages.<system>.default` | derivation | Alias for `packages.<system>.rtk`. |
| `apps.<system>.default` | app | `nix run` wrapper around `bin/rtk`. |
| `checks.<system>.rtk` | derivation | Same build, exercised by `nix flake check`. |

Supported `<system>`: `x86_64-linux`, `aarch64-linux`, `x86_64-darwin`, `aarch64-darwin` —
the four Nix default systems, matching rtk's four published release tarballs one-for-one.
(Upstream also publishes a Windows `.zip` and x86_64 `.deb`/`.rpm`; neither maps to a Nix
platform.) The pinned `version` and per-asset hashes live in [`package.nix`](package.nix);
there is no override mechanism for the version — bump it via `update.sh` (see below) rather
than `overrideAttrs`, since the hash is tied 1:1 to the pinned version.

## Staying current

`update.sh` checks rtk's latest **stable** release (tagged `vX.Y.Z`; the frequent
`dev-*-rc.N` pre-releases are intentionally skipped) and rewrites `package.nix` with the new
version and per-platform hashes. The `update-check` GitHub Actions workflow runs this daily
and opens a PR when a new stable release is found — no manual hash-bumping needed.

Run it by hand:

```sh
./update.sh
nix flake check
```

## Contributing

There's no `CONTRIBUTING.md` yet — for now, issues and PRs are welcome directly on this repo,
particularly reports of upstream release-asset renames or an rtk version that breaks
`update.sh`'s detection. See [Provenance and handover intent](#provenance-and-handover-intent)
below if you're an rtk maintainer.

## Provenance and handover intent

This repo was created by [@tburny](https://github.com/tburny) to solve a personal binary-cache
problem across several downstream projects. It's deliberately self-contained (own repo, own
Cachix cache, own CI) so it can be handed over to or adopted by the rtk maintainers (`rtk-ai`)
once it's proven out, rather than staying a permanent third-party dependency.

Folding Nix packaging in-tree is already under discussion upstream in
[rtk-ai/rtk#457](https://github.com/rtk-ai/rtk/issues/457) ("Would you accept a nix config?"),
with [rtk-ai/rtk#609](https://github.com/rtk-ai/rtk/pull/609) open against it. That PR builds
rtk from source with `rustPlatform.buildRustPackage`; this repo deliberately takes the other
approach — fetching the prebuilt release binaries — so the two answer different questions and
are complementary rather than competing. An in-tree source build tracks the working tree at any
commit, which a release-pinned flake cannot; a prebuilt flake with a binary cache spares every
consumer a Rust toolchain, which an uncached source build cannot. Either could supersede this
repo. If you're an rtk maintainer and want to adopt this packaging, please open an issue —
happy to transfer.

## Licensing

This repo's own packaging code (`flake.nix`, `package.nix`, `update.sh`, CI) is MIT-licensed
— see [`LICENSE`](LICENSE). The rtk binaries this repo fetches and distributes are themselves
licensed under Apache-2.0 by their upstream project; see
[rtk's LICENSE](https://github.com/rtk-ai/rtk/blob/master/LICENSE) for the terms that apply to
the binary itself.
