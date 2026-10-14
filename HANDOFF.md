# Handoff

P5 of brief 19 ran on 2026-10-14: the real image, the build CI and the Flatpak
publishing. The image was built, installed to a blank disk under Secure Boot and
a TPM, rebooted and checked. `build.yml` has run once on GitHub, on the push of
this work: with no `OS_AGENT_TOKEN` it took 6 s, wrote the warning and the summary,
and ended green (run 38500193127). **The build itself has never run there**, the
publish workflow has never run at all, and nothing was published or pushed to any
registry.

## What is here

- `Containerfile`: a builder stage for `mauvelyd` (Fedora 44, `cargo build
  --release --locked`), then the pinned Kinoite base with:
  - `/usr/bin/mauvelyd` and its unit, enabled. It starts only when
    `/etc/mauvely/server` exists.
  - `mauvely-seal.service` and `/usr/libexec/mauvely/seal` (below).
  - Firefox and `firefox-langpacks` removed (the only browsers in the base).
  - Masked: `bootc-fetch-apply-updates` and `rpm-ostreed-automatic` (timer and
    service each), and `flatpak-add-fedora-repos.service`.
  - `/usr/lib/bootc/install/50-mauvely.toml`: xfs, and `block` spelled out.
  - `os-release` rewritten to Mauvely OS, and `/etc/xdg/kcm-about-distrorc` with
    the logo (`Git/resources/Logos/1024/favicon_dark.png`, 512 px) and
    `https://mauvely.com`.
  - `RUN bootc container lint` last: 14 checks passed, 1 skipped, no warnings.
  - Plasma Setup untouched; `/etc/plasma-setup-done` is not written.
- `agent.ref`: the os-agent commit built in (`69ca2d0`, which is pushed).
  `scripts/build.sh` is the one way to build; it warns when `../agent` is at
  another commit or has uncommitted changes.
- `rootfs/`: the files copied over `/`.
- `keys/mauvely-flatpak.gpg`: the public key. Its fingerprint is
  `C9094B2147C0E6AF28E8CC7FFDC884F8E872CE0A`, and its bytes equal the base64
  `FLATPAK_GPG_KEY` in website-devices' `wrangler.jsonc`, both the production and
  staging values. `~/mauvely-flatpak-public.gpg` is still there for Timur to delete.
- `scripts/publish-flatpak.sh`, `scripts/test-publish-flatpak.sh` and the two
  workflows in `.github/workflows/`.
- `spikes/p5-install.sh` and `spikes/p5-evidence.sh`: the VM test. `spikes/env.sh`
  now takes the three ports from the environment, and `Containerfile.spike` takes
  `ARG BASE`. Nothing else in `spikes/` changed.

### The seal unit: `mauvely-seal.service`

Runs at **every boot**, before `mauvelyd.service`, and does nothing on a machine
that is already right. That is deliberate (the brief said "first boot"): it needs
no marker, and it repairs a first boot that died halfway.
- If the root LUKS2 token is bound to no PCRs, it runs `systemd-cryptenroll
  --unlock-tpm2-device=auto --tpm2-device=auto --tpm2-pcrs=7 --wipe-slot=tpm2`.
  The device comes from `findmnt /sysroot` and `cryptsetup status`, never a name.
- If `/proc/cmdline` has `luks.options=tpm2-device=auto,headless=true`, it runs
  `rpm-ostree kargs --delete=… --append=luks.options=tpm2-device=auto`. It never
  reboots.
- **It skips the kargs job when a deployment is already staged.** `rpm-ostree
  kargs` builds from the booted deployment, so it would replace an image the agent
  had staged, and the same holds the other way round: `bootc switch` run after the
  seal staged its kargs-only deployment discards that fix. Either way the fix
  lands on a later boot. It converges, but it can take two reboots.
- It never wipes the recovery slot, and does not add one: the installer does.

## Verified, and how

All in the VM (Fedora Cloud installer VM, `bootc install to-disk --block-setup
tpm2-luks`, OVMF Secure Boot with swtpm), image `localhost/mauvely-os:p5` plus the
one-line `sshd` layer from `Containerfile.spike`. The installed machine therefore
differs from the plain image by `sshd` being enabled, and by nothing else.
Proof is in `proof/p5/`.

| Check | Result | Proof |
|---|---|---|
| Rootless `podman build`, lint | Passes, 14 checks, no warnings | `build-lint.txt` |
| Install without `--filesystem` | **Works**: bootc made xfs from the image's config | `install-log.txt` |
| `mauvelyd` present, enabled | `/usr/bin/mauvelyd`, `enabled`, `inactive` with no `/etc/mauvely/server` | `evidence-first-boot.txt` |
| `mauvelyd` starts under its unit | Starts, says "not enrolled" with no token. Not run against a server | `evidence-mauvelyd-starts.txt` |
| Seal ran once at first boot | Token `tpm2-pcrs: [7]`, slots `0 recovery` and `2 tpm2`; kargs staged | `evidence-first-boot.txt` |
| Recovery slot survives | The recovery key (kept on the host, never printed) still opens the volume | same file |
| `systemctl restart mauvely-seal` | No-op: "already names PCRs", "a deployment is already staged" | end of `evidence-first-boot.txt` |
| Reboot | No prompt, `luks.options=tpm2-device=auto`, seal a no-op, nothing staged | `evidence-after-reboot.txt` |
| Secure Boot off | Boot stops at "Please enter recovery key", typing it boots | `evidence-secure-boot-off.txt`, `p5-sb-off-recovery-prompt.png` |
| os-release | `NAME="Mauvely OS"`, `ID=fedora`, `VERSION_ID=44`. Plasma Setup says "Powered by Mauvely OS" | first-boot evidence, `p5-first-boot-plasma-setup.png` |
| No Flatpak remotes | `flatpak remotes --system --show-disabled` prints nothing | after-reboot evidence |
| Update units | The four are `masked`; only `rpm-ostree-countme.timer` is listed | both evidence files |
| Firefox gone | No RPM, no `.desktop` | both evidence files |
| Publish script | Both apps on `stable`, signatures enforced, wrong key refused, re-run changes nothing, works on a files-only repo (what R2 returns) | `publish-flatpak-local.txt` |
| Workflow shell, gates | `shellcheck` clean on every `run:` block; the missing-secret paths exit 0; key import accepts armored and base64 and refuses a wrong key | run locally, not saved |

`systemctl --failed` showed `mcelog.service` (a VM has no machine checks) and the
journal showed `tuned` AVCs on `chcon`. Both are the base image, not this change.

## Decisions where the brief was open or wrong

- **bootc's install config needs `block` spelled out.** With
  `[install.filesystem.root]` and nothing else, bootc reads a missing `block` as
  `["direct"]` and refuses `--block-setup tpm2-luks` ("Block setup Tpm2Luks is not
  enabled in installation config"). `50-mauvely.toml` lists
  `block = ["direct", "tpm2-luks"]`. **The installer (P6) may drop `--filesystem`.**
- **The Flatpak repo lives under `repo/` in the bucket**, because website-devices
  hands devices `https://flatpak.mauvely.com/repo`. The R2 custom domain then needs
  no rewrite. If Timur wants it at the bucket root, change `R2_PREFIX` in
  `publish-flatpak.yml` and the URL together.
- **The bundle is imported into a scratch repo and `build-commit-from
  --src-repo` copies it to `stable`.** The published repo never has a `master`
  ref. A second run reports "no change". `build-update-repo` also gets
  `--default-branch=stable`, so a client that names no branch gets `stable`.
- **The publish script recreates the empty directories** (`refs/remotes`, `tmp`, …).
  R2 holds files only, so a repo synced down is missing them and `ostree` refuses
  to open it. That failed in testing before the fix.
- **Nothing is deleted from R2.** The upload is `sync` without `--delete`, so
  pruned objects stay there. They are small and harmless.
- **Cache headers follow the brief:** `objects/` and `deltas/` for a year,
  immutable; everything else `no-cache`. `summaries/` is content-addressed and could
  be immutable too; it is left revalidated.
- **Only a key with no passphrase is supported.** If `FLATPAK_GPG_KEY` has one, gpg
  would need `gpg-preset-passphrase`, which is not written.
- **os-release:** `PRETTY_NAME="Mauvely OS (Fedora 44 base)"`; the Fedora Kinoite
  support and bug URLs are removed and `HOME_URL` is mauvely.com. `DEFAULT_HOSTNAME`
  is still `fedora`. `/usr/lib/mauvely-release` is gone, since os-release covers it.
- **`fedora-third-party-refresh.service` is left alone.** It does nothing until
  someone runs `fedora-third-party enable`.
- **The image is 7.47 GB on disk, 0.1 GB more than the base**, because removing
  Firefox leaves its files in the base layers and adds a rewritten RPM database.
  Devices pull the full layers. Rechunking would fix it, and is not done.

## What Plasma Discover still does with OS updates (not fixed, as asked)

Read from the image, **not seen running**, since no user session was started:
- `/etc/xdg/PlasmaDiscoverUpdates` has `UseUnattendedUpdates=true`, and
  `org.kde.discover.notifier` autostarts, with `plasma-discover-rpm-ostree` as the
  backend.
- polkit's `org.projectatomic.rpmostree1.rules` lets **any active local user**, not
  only `wheel`, run `rpm-ostree upgrade` and `repo-refresh` without a password.
- So Discover can stage an update of the booted origin's ring on its own and ask for
  a restart. It does not reboot by itself. It bypasses the admin's collection and,
  later, the maintenance windows.
- To close it: set `UseUnattendedUpdates=false`, drop the `upgrade` rule for
  non-admins, or remove `plasma-discover-rpm-ostree` and the notifier.

Other things the base does that nobody asked about: **`rpm-ostree-countme.timer` is
enabled** (described as a weekly anonymous count; it runs 5 minutes after boot and
every 3 days, and reports to Fedora's mirrors, which a sovereignty pitch may not want), and the default browser is still `org.mozilla.firefox.desktop` in
the mimeapps lists, which is the id Flathub's Firefox also uses, so it will match
once that is installed.

## Never run, or not for real

- **Neither workflow has done its real work on GitHub.** Untested there: rootless
  podman on `ubuntu-latest` (user namespaces, podman 4.9's `--build-context`, and
  the label moves to Ubuntu 26 on 2026-10-19), the disk reclaim, build time, and
  for the publish workflow `apt install flatpak ostree`
  (Ubuntu's Flatpak is 1.14, the local tests used 1.18.4), the `aws` CLI against R2
  and the upload order. The key import was tried with a throwaway key only: the
  refusal paths work, and **the real key's success path has never run**.
- The `mauvelyd` unit's hardening has now started the binary on Kinoite, but the
  agent has never met website-devices.
- A real machine's PCR 7: a firmware or `dbx` update changes it, the TPM then
  refuses, and the user types the recovery key. Nothing re-seals afterwards. That
  is M3.
- The kargs fix on a machine whose first reboot comes after the agent has staged an
  image (the converging case above) was reasoned, not run.
- The installer is P6's. No code here writes `/etc/mauvely/{server,enrol}` or
  adds the recovery key; `spikes/p5-install.sh` does the second by hand to
  imitate it.

## Waiting for Timur

- **`OS_AGENT_TOKEN`**, a token that can read `Mauvely/os-agent`, as an Actions
  secret, **or** make os-agent public (the gate then needs no secret). Until then
  `build.yml` writes a warning and a summary and ends green without building.
- **R2 secrets for the publish workflow:** `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`,
  `R2_SECRET_ACCESS_KEY` (an R2 API token with Object Read & Write on
  `mauvely-flatpak`). `FLATPAK_GPG_KEY` exists already. With any missing, the run
  says which and ends green. Also the `flatpak.mauvely.com` custom domain on the
  bucket, serving `/repo/…`.
- **T4**, the image registry, and then `policy.json` signature enforcement. The
  installed machine reports `ostree-unverified-registry:registry.invalid/…`, and
  that stays so until both.
- Delete `~/mauvely-flatpak-public.gpg`.
- Decide: Discover, and `rpm-ostree-countme.timer`, above.
- Plan 20 (ids to `com.mauvely.*`): the publish script reads ids from the bundles,
  so the first publish after the move adds the new refs. The old
  `app/net.mauvely.*` refs stay in the remote until someone runs `ostree refs
  --delete` on them, and a device with the old id assigned has to be migrated.

## Tried and rejected

- Putting the repo at the bucket root: contradicts the URL the plane sends.
- Importing the bundle with `--ref` instead of `build-commit-from` (as before).
- A `.containerignore`: the context is a few files.
- Heredocs in the `Containerfile`: older podman on runners may not parse them, so
  `os-release` is edited with one `sed`, and the build fails if a line did not match.

## On this machine

`~/.cache/mauvely-os/p5/` is about 23 GB, nearly all of it `machine/` (the installed
VM, its OVMF vars, swtpm state and `recovery-key.txt`, which is for a throwaway disk).
It also has the throwaway gpg homes, `publish-test/` and the build logs. Safe to
delete. The images `localhost/mauvely-os:p5` and `:p5-ssh` are in podman storage.
No VM, `swtpm` or seed server of this session is left running. P6's VMs were not touched.
