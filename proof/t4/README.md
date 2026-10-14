# T4: the image signature policy, on real bootc, 2026-10-14

What brief 19's T4 rests on, tried before any image goes to GHCR:
- a device refuses an image under `ghcr.io/mauvely/os` unless Mauvely's key
  signed it;
- `bootc upgrade`, which the agent now runs when the booted image is the wanted
  one, stages a newer build under the same tag.

## The setup

- **The images:**
  - the image from branch `t4-ghcr` (`071969a`), built with a throwaway cosign
    key as `keys/cosign.pub`;
  - with sshd enabled on top, as the spikes' `Containerfile.spike` does, so the
    VM could be reached after the reboot;
  - variants that differ only in a label, so each has its own digest.
- **The registry:** a local `docker-distribution` on `127.0.0.1:5055`. The VM
  reaches it as `10.0.2.2:5055`, and its `registries.conf.d` marks it insecure.
- **The VM:**
  - a copy-on-write overlay of P5's installed disk (`proof/p5/`), with copies
    of its TPM state and OVMF vars, so P5's machine was not touched;
  - Secure Boot, swtpm, bootc 1.16.13, skopeo 1.22.3, containers-common 0.67.2.
- **The policy in the VM:** the Containerfile's own `policy.json` rule and
  `registries.d/mauvely-os.yaml`. Only the scope differs: `10.0.2.2:5055/mauvely/os`
  in place of `ghcr.io/mauvely/os`.
- **Signing:** cosign v2.6.5, run inside the VM, so that the signature names the
  repository as the VM sees it. `--tlog-upload=false`: nothing went to Rekor.
- **Transport:** plain `bootc switch <ref>`, which is `ostree-unverified-registry`.
  There was no `--enforce-container-sigpolicy`.

## What happened

| Step | bootc said | Staged afterwards |
|---|---|---|
| `bootc switch …/mauvely/os:unsigned` | `A signature was required, but no signature exists`, exit 1 | nothing |
| `bootc switch …/mauvely/os:stable`, signed | queued, digest `f508…bd1` | `f508…bd1` |
| `bootc switch …:unsigned` after signing it with a **different** key | `invalid signature when validating ASN.1 encoded signature`, exit 1 | still `f508…bd1` |
| reboot | booted `10.0.2.2:5055/mauvely/os:stable` `f508…bd1`, Mauvely OS, no LUKS prompt | nothing |
| `bootc upgrade`, nothing new | `No update available.`, exit 0 | nothing |
| push a newer signed build to `:stable`, `bootc upgrade` | 267 layers, exit 0 | `1015…d58`, same ref |
| `bootc upgrade` again | `Staged update present, not changed`, exit 0 | `1015…d58` |
| push an **unsigned** build to `:stable`, `bootc upgrade` | `A signature was required, but no signature exists`, exit 1 | still `1015…d58` |

`scripts/test-image-policy.sh` shows the same thing with skopeo, in a container
from the image. In that test, cosign v3's default bundle format came out
`A signature was required, but no signature exists` for an image it had signed.
That is why `publish-image.yml` pins cosign v2.

## What this did not show

- **GHCR itself**, the real key and Rekor. The first `publish-image.yml` run is
  the first time any of the three is involved. See "On GHCR" below.
- **A changed `/etc/containers/policy.json`.** After the reboot the VM still
  held its own edited file, not the new image's. This is ostree's `/etc` merge:
  a file changed locally is kept whole. A device whose policy file someone
  edited would keep that file, and would not take a future change to the policy
  or the key from an image. Users have no root, so on a managed machine only
  the break-glass account could cause this (M2).
- **`mauvelyd` itself.** It was not run here. The agent's change is one argv,
  `bootc upgrade`, and is unit-tested in os-agent.

## On GHCR, 2026-10-14 afternoon

`publish-image.yml` `next` (run 38567573684) pushed and signed
`ghcr.io/mauvely/os:next`, digest `sha256:ccf06254…7e88`, with the real key
(Rekor entry 3250603642). Its own pull-back through the image's policy passed.
After that, Timur made the package public.

**The device side**, through staging, with nothing local but the VM:

- **The VM** was a fresh overlay of P5's installed disk, its own copy of the TPM
  state and OVMF vars, booted on `registry.invalid/mauvely/os:p5`.
  - One local addition: a `graphical.target.wants/sshd.service` link in
    `/etc`, so the VM could still be reached after the switch. ostree keeps a
    local addition; the GHCR image does not enable sshd.
- **website-devices staging** had `OS_IMAGE_REPO = ghcr.io/mauvely/os`.
  - In the test org on enterprise.mauvely.dev, a collection on `Next` with a
    1-minute check-in, and a single-use token for it.
- **`/etc/mauvely/server`** was `https://devices.mauvely.dev`. It was the first
  time the agent talked HTTPS to a real host; its roots are built in
  (`webpki-roots`).

| Time (UTC) | What happened |
|---|---|
| 13:20:59 | `mauvelyd` (P5's, `69ca2d0`) enrolled into the org, and was told `ghcr.io/mauvely/os:next` |
| 13:21:00 | `bootc switch`: 257 layers already present, 9 needed (36 MB) |
| 13:21:41 | staged `sha256:ccf06254…7e88`, the digest the publish signed |
| reboot | booted `ghcr.io/mauvely/os:next` at that digest. The disk unlocked with no prompt. `Mauvely OS (Fedora 44 base)`. `policy.json` holds the `sigstoreSigned` rule, and `/etc/pki/containers/mauvely-os.pub` hashes to `keys/cosign.pub`'s sha256 |
| 13:22:12 | the new `mauvelyd` (`09b2536`) checked in, and ran `bootc upgrade` each minute after: nothing new, nothing staged |
| 13:23 | the console's device page showed the image `ghcr.io/mauvely/os:next`, the same digest, Secure Boot and TPM |

**The first switch was not checked.** P5's image has no rule for GHCR, so it
pulled under accept-anything. That is true of every machine from before T4.

**Not yet shown:** a device staging a newer `next`. That is the first time a
device checks the real key's signature itself. It waits for a second
dispatch.
