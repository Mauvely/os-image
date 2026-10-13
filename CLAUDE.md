# os-image

The Mauvely OS image: a `Containerfile` on top of Fedora Kinoite. It also holds
the CI that builds the image and publishes the Mauvely Flatpak remote.

The design, the decisions and the milestone map are in brief 19:
`Website/website-internal/docs/launch/plans/19-mauvely-os.md` in the Mauvely
superproject. Read it before changing anything here.

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
- **Ids must agree with the apps' own.** Flatpak app ids are the apps'
  reverse-DNS ids (`net.mauvely.*`), byte for byte, or Wayland loses the window
  icon.

## Handing off

`HANDOFF.md` is overwritten each session. It holds what is half-done, what was
tried and rejected, and what compiles but has never run.
