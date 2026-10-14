# os-image

The Mauvely OS image: a `Containerfile` on top of Fedora Kinoite. It also holds
the CI that builds the image and publishes the Mauvely Flatpak remote.

The design, the decisions and the milestone map are in brief 19:
`Website/website-internal/docs/launch/plans/19-mauvely-os.md` in the Mauvely
superproject. Read it before changing anything here.

## Layout

| Path | Holds |
|---|---|
| `Containerfile` | The image: a builder stage for `mauvelyd`, then Kinoite plus `rootfs/` |
| `agent.ref` | The os-agent commit the image is built from. Moving it is a deliberate commit |
| `rootfs/` | Files copied over `/` in the image: the seal unit and script, the bootc install config, branding |
| `scripts/build.sh` | The one way to build, locally and in CI. Warns when `../agent` is not at `agent.ref` |
| `scripts/publish-flatpak.sh` | Bundles from the release feed into the signed Flatpak repo. `test-publish-flatpak.sh` tries it with a throwaway key |
| `keys/` | The Flatpak signing key's public half |
| `.github/workflows/` | `build.yml` (build and lint, pushes nowhere) and `publish-flatpak.yml` (by hand only) |
| `spikes/` | The P1 spike scripts, reused for VM tests. `proof/` holds what the runs showed |

## Rules

- **Never push an image to a registry** until the registry choice is made (T4
  in brief 19).
- **Never commit a private key.** The Flatpak signing key's private half lives
  only in the Actions secret `FLATPAK_GPG_KEY`.
  - Its public half is committed here.
  - Its fingerprint is `C9094B2147C0E6AF28E8CC7FFDC884F8E872CE0A`. Check any
    public key file against it.
- **The base image tag is pinned**, never `latest`. Moving it is a deliberate
  commit.
- **Publishing the Flatpak remote is Timur's call.** A session does not
  dispatch `publish-flatpak.yml`, and tries the script only with a throwaway
  key (`scripts/test-publish-flatpak.sh`).
- **`bootc install`, the seal script and anything else that touches a disk run
  in a VM** (`spikes/`), never on the host.
- **Ids must agree with the apps' own.** Flatpak app ids are the apps'
  reverse-DNS ids (`net.mauvely.*`), byte for byte, or Wayland loses the window
  icon.

## Handing off

`HANDOFF.md` is overwritten each session. It holds what is half-done, what was
tried and rejected, and what compiles but has never run.
