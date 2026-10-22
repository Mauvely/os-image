# M2 spike: a second question at the login screen

Brief 26 (website-internal `docs/launch/plans/26-os-login.md`, "Spike results" and
"Proved on the VM") is the write-up; this directory is what it ran. Nothing here is in
the image.

| File | What it is |
|---|---|
| `plm-second-prompt.patch` | Plasma Login Manager 6.7.5 (Fedora f44, as `Patch1003`): a PAM question after the password reaches the greeter as a second field, labelled with the module's own text |
| `plm-second-prompt-6.8.1.patch` | The same against 6.8.0, 6.8.1 and `Plasma/6.8`, not yet built |
| `lockscreen-second-prompt.patch` | Optional, plasma-desktop's lock screen QML: clears the box and uses the module's label for a second secret prompt. Not yet built |
| `plm-build.Containerfile` | Builds the patched RPMs from Fedora's signed source RPM |
| `pam_toycode.c` | A toy module for the VM: `pam_toycode.so password` takes any answer as the password, so no real one is typed; bare, it asks "Code:" after a `pam_info` and accepts 123456. Never ship it |
| `login-code-prompt.png`, `lock-code-prompt.png` | The greeter and the lock screen asking for the code on `mauvely-01`, 2026-10-22 |

To try it on the VM: `rpm-ostree usroverlay`, `rpm -Uvh --force` the two RPMs, install
the toy module to `/usr/lib64/security/`, put the toy lines in place of
`substack password-auth` in a copy of `/usr/lib/pam.d/plasmalogin` at
`/etc/pam.d/plasmalogin`, move the dev autologin drop-in aside, and
`systemctl restart plasmalogin`. Put `/etc` back afterwards: the overlay goes at
reboot, `/etc` does not.
