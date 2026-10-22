# os-image

The Mauvely OS image: a `Containerfile` on top of Fedora Kinoite. It also holds
the CI that builds the image and publishes the Mauvely Flatpak remote.

The design, the decisions and the milestone map are in brief 19:
`Website/website-internal/docs/launch/plans/19-mauvely-os.md` in the Mauvely
superproject. Read it before changing anything here.

## Layout

| Path | Holds |
|---|---|
| `Containerfile` | The image: builder stages for `mauvelyd`, `mauvely-signin` and Breeze's window decoration, then Kinoite plus `rootfs/` |
| `agent.ref` | The os-agent commit the image is built from. Moving it is a deliberate commit |
| `installer.ref` | The os-installer commit `mauvely-signin`, the sign-in window, is built from (its `signin/`). Moving it is a deliberate commit |
| `rootfs/` | Files copied over `/` in the image: the seal unit and script, the bootc install config, branding, the Mauvely look (global themes, KDE defaults in `/usr/share/mauvely/xdg`, Plymouth theme) |
| `rootfs/usr/lib/systemd/system/var-lib-flatpak-extension-*.mount` | The browser extension (brief 22, S4; os-agent `docs/browser.md`): each binds a tree of `/usr/share/mauvely/browser/` where Flatpak mounts it into Firefox or Chromium. The trees are the `browser` build context, which `scripts/build.sh` stages with os-agent's `browser/package.py` |
| `patches/breeze/` | Applied to Fedora's Breeze source in the image's build: the `CornerRadius` key behind the look's 8 px window corners |
| `scripts/build.sh` | The one way to build, locally and in CI. Warns when `../agent` is not at `agent.ref`, or `../installer` not at `installer.ref` |
| `scripts/bump-base.sh` | Moves the Kinoite pin to the newest build of the same release. The weekly run of `publish-image.yml` uses it |
| `scripts/publish-flatpak.sh` | Bundles from the release feed into the signed Flatpak repo. `test-publish-flatpak.sh` tries it with a throwaway key |
| `scripts/test-image-policy.sh` | Tries a built image's signature policy against a throwaway registry and throwaway cosign keys |
| `keys/` | The public halves: `mauvely-flatpak.gpg` for the Flatpak remote, `cosign.pub` for the image |
| `.github/workflows/` | `build.yml` (build and lint, pushes nowhere), and `publish-image.yml` and `publish-flatpak.yml` (by hand, apart from the weekly `next`) |
| `spikes/` | The P1 spike scripts, reused for VM tests. `proof/` holds what the runs showed |
| `design/plasma/` | Brief 25's phase-1 prototype of the look, and the generators for its colour schemes and wallpaper |

## Rules

- **Images go to `ghcr.io/mauvely/os` through `publish-image.yml` only**, and
  dispatching it is Timur's call (T4 in brief 19). A session never pushes an
  image and never dispatches the workflow. It tries the policy with
  `scripts/test-image-policy.sh`.
  - **One exception (Timur, 2026-10-16; brief 22):** the workflow's weekly
    schedule moves the Kinoite pin within the same Fedora release, commits it
    and publishes `next`. It never publishes `stable`.
- **The image signature must be one containers/image can find.** cosign v3's
  default bundle format is not, and an image signed that way is refused by
  every device. `publish-image.yml` says why it pins v2. Change the version or
  the flags only once `test-image-policy.sh` passes with them.
- **Never commit a private key.** The Flatpak signing key's private half lives
  only in the Actions secret `FLATPAK_GPG_KEY`, and the image key's only in
  `COSIGN_PRIVATE_KEY`.
  - Both public halves are committed here.
  - The browser extension's keys are Actions secrets too: `CRX_SIGNING_KEY`,
    `AMO_JWT_ISSUER` and `AMO_JWT_SECRET`, read only by `publish-image.yml`.
    A throwaway CRX key for a test stays under `~/.cache/mauvely-os/`.
  - The Flatpak key's fingerprint is
    `C9094B2147C0E6AF28E8CC7FFDC884F8E872CE0A`. Check any public key file
    against it.
  - `keys/cosign.pub` (P-256, made 2026-10-14) has the sha256
    `62388839b87ecd602f8d372fd57a6f654cec69635c3ddcef877aefeeda836aee`. A change to it is a key rotation: every device keeps trusting
    the old key until it boots an image that carries the new one.
- **The base image tag is pinned**, never `latest`. The weekly schedule moves
  it to the newest dated build of the same release (`scripts/bump-base.sh`).
  A new Fedora release is a deliberate commit.
- **Publishing the Flatpak remote is Timur's call.** A session does not
  dispatch `publish-flatpak.yml`, and tries the script only with a throwaway
  key (`scripts/test-publish-flatpak.sh`).
- **`bootc install`, the seal script and anything else that touches a disk run
  in a VM** (`spikes/`), never on the host.
- **Ids must agree with the apps' own.** Flatpak app ids are the apps'
  reverse-DNS ids (`com.mauvely.<key>`, since plan 20; `net.mauvely.<key>.app`
  before), byte for byte, or Wayland loses the window icon.

## Handing off

`HANDOFF.md` is overwritten each session. It holds what is half-done, what was
tried and rejected, and what compiles but has never run.
