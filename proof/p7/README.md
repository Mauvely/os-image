# P7: the end-to-end demo, 2026-10-14

Brief 19's milestone 1, run once from start to finish on this machine:
install, enrol by token, apps installed from the collection, one app
unassigned and removed, the device revoked.

## The setup

- **The servers:**
  - website-devices (`main` `5a6adcd`) on 8798;
  - website-enterprise (branch `os/devices-console`) on 8791, forwarding
    `/api/enterprise/devices/*` over the real service binding.
  - Both use a scratch miniflare store, not `Website/.mauvely-local`.
  - The store holds a test organisation, "Office Demo Ltd", with one admin and
    a forged session.
- **The Mauvely remote:**
  - built by `scripts/publish-flatpak.sh`, holding Compose 0.5.3 on `stable`;
  - signed with the spike's throwaway key, not the production key;
  - served at `http://127.0.0.1:8120/repo`.
  - website-devices hands it to the agent through `--var FLATPAK_REMOTE_URL`
    and `--var FLATPAK_GPG_KEY`.
- **The collection:** "Office Machines" checks in every 60 s and holds Compose
  (mauvely), plus Firefox, ONLYOFFICE and Chromium (Flathub).
- **The enrolment token:**
  - made through the console API, for that collection;
  - single use, valid for one day.
- **The VM:** qemu with OVMF Secure Boot, the Microsoft and Red Hat keys,
  swtpm and a blank disk (os-installer's `scripts/vm.sh`).
- **The ISO:** os-installer's `mauvely-installer-p6-p5-test.iso`.
  - Its payload is P5's image.
  - Its test layer adds root SSH and `mauvely.server=http://10.0.2.2:8798`.

## What happened

| UTC | |
|---|---|
| 03:05:14–03:07:52 | The installer, after Welcome, the server and the pasted token, `vda` and "Erase and install": bootc, the recovery key, the two files, "Installed." Then the recovery key page, Finish and Restart |
| 03:10:11 | The first boot. `mauvely-seal` re-enrols the TPM on PCR 7 and drops `headless=true` |
| 03:10:34 | `mauvelyd` enrols with the token, deletes `/etc/mauvely/enrol`, and checks in |
| 03:10:46 | Compose is installed from the mauvely remote, with GPG checked on the summary and the commit |
| 03:11:03 | Chromium, Firefox and ONLYOFFICE are installed from Flathub. All four arrived within 30 s of enrolment |
| 03:11:24 | Chromium is unassigned in the console API |
| 03:12:09 | Chromium is uninstalled on the next check-in, along with its Codecs and Locale extensions |
| 03:14:47 | The device is revoked in the console API |
| 03:15:10 | A check-in gets `403 revoked`. The agent logs it and stops checking in. The machine keeps its apps |

The device shows in the console under Office Machines, with its hardware
(TPM 2.0 and Secure Boot both yes), its booted image and digest, and an
inventory of three managed apps. The audit API holds every step:

- `collection.create`;
- the four `collection.app.set`;
- `token.create`;
- `device.enrol`, with the token's id and never the token;
- `collection.app.remove`;
- `device.revoke`.

## Files

| File | Holds |
|---|---|
| `evidence-vm.txt` | From the installed machine after the run: os-release, Secure Boot, the LUKS slots, `/etc/mauvely` with its label, the remotes and their config, the installed apps, and the seal and agent journal |
| `evidence-server.txt` | The agent's requests as website-devices logged them, the times, and the console API's device, collection apps and audit answers |
| `install-live.log` | The installer's own log from the live system |
| `installer-done.png` | The installer's last page |
| `vm-plasma-setup.png` | The installed machine's screen: Plasma Setup, "Powered by Mauvely OS" |
| `console-devices-revoked.png`, `console-device-inventory.png`, `console-collection-apps.png` | The enterprise console, from headless Chromium |

## Checks

**Secrets:**
- Neither the enrolment token nor the session cookie appears in any file here,
  nor in the live system's journal; each was checked with `grep -F`.
- The recovery key page was not kept.
- Nothing here matches the recovery key's shape.

**Compose:** `MauvelyCompose` started from the Flatpak under the offscreen
platform and kept running until it was killed. A visible launch with its icon
is P1's spike 3.

## What this run did not show

- **The console's Audit log page shows nothing.** It reads
  `enterprise_audit`, and device actions are in website-devices'
  `devices_audit`. The data is there, behind `GET /api/devices/v1/audit`, and
  nothing in the console shows it yet.
- **The hostname is `fedora`, so the device is named "fedora".** This is
  already open for M2/M3.
- **The image is not managed.** The collection's image is "Not managed", and
  `booted_image` is the `registry.invalid` placeholder until T4. `bootc
  switch` has only been unit-tested.
- **A revoke leaves the machine as it was:** apps, remotes and the agent's
  key. Wipe is M3.
- **The `absent` state** (removing an app a person installed) was not
  exercised here. It is covered by tests in os-agent and website-devices.
