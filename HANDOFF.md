# Handoff

P1 (the three spikes, brief 19) ran on 2026-10-14. All three pass. The results,
versions, traps and the P6 recommendation are in brief 19's "Spike results (P1)"
(`Website/website-internal/docs/launch/plans/19-mauvely-os.md`). This file holds
only what the next session needs that the brief does not say.

## What is here

- `Containerfile`: the pinned Kinoite 44 base (`44.20261013.0`), a
  `/usr/lib/mauvely-release` marker, `bootc container lint`. **It has no real
  contents yet.** P5 fills it.
- `spikes/`: everything to redo the spikes. Run order, from a shell with the venv
  at `~/.cache/mauvely-os/venv` (`pip install virt-firmware`):
  `s1-prepare.sh`, then serve `~/.cache/mauvely-os/seed` on port 8099, then
  `vm.sh installer`, `s1-transfer.sh`, `s1-install.sh`, `vm.sh stop`,
  `vm.sh target`. S3 is `s3-build-repo.sh` and a `python3 -m http.server`.
  `s2-bib.sh` and `s2-generic-iso.sh` are the two ISO paths, and `iso-boot.sh`
  boots an ISO. `installer/` is the stand-in installer image.
- `spikes/Containerfile.spike` is a layer that only enables `sshd`. The installed
  machines carry it, so they are not byte-identical to the plain image.
- `spikes/proof/`: screenshots and text from the runs.

## Not done, or never run

- **No Qt installer app.** The live environment ran a shell script. A compositor, Qt
  and NetworkManager in the installer image are untried.
- **The four jobs bootc does not do** (brief 19, S2 recommendation 2) are written
  down and were each done by hand, but no agent or installer code does them yet:
  re-enrol the TPM on PCR 7, add and escrow a recovery key, drop `headless=true`,
  and write `/etc/plasma-setup-done`.
- **The Containerfile does not set the filesystem.** `bootc install` needs
  `--filesystem xfs` on the command line. `/usr/lib/bootc/install/*.toml` would
  carry it; not tried.
- **Image signatures are not checked.** The installed machines show
  `ostree-unverified-registry:`. The target reference in the spikes is
  `registry.invalid/mauvely/os:spike`, which exists nowhere. T4 (the registry)
  is still open.
- **Compose's Flatpak is on `master`**, not `stable`. Re-branching with
  `flatpak build-commit-from` works; the Compose repo is untouched.
- **Snap has no Linux build.** The M1 demo's "Snap" has nothing to install.

## Tried and rejected

- `flatpak build-import-bundle --ref=…/stable`: publishes, fails on install (the
  ref binding in the commit still says `master`).
- `rpm-ostree kargs --replace=luks.options=…`: cannot parse a value with `=`.
- Masking `udisks2`, and a `nowatch` udev rule, to stop bootc's LUKS close from
  failing in the live system. Neither helped; the cause is a leaked
  `/run/bootc/storage` mount.
- `podman run … <payload> bootc install` inside the live system: hung with no
  output for over ten minutes, not investigated.

## On this machine

`~/.cache/mauvely-os/` holds about 55 GB: `machine/` (the installed VM, its OVMF
vars and swtpm state), `iso/` (two ISOs, 8 GB), `isotest-*/`, `flatpak-repo/` and
the throwaway GPG key in `spike-gpg/`. None of it is committed. The helper
`python3 -m http.server` processes on ports 8097, 8098 and 8099 were stopped at
the end of the session.
