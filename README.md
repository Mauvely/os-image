# Mauvely OS image

The Mauvely OS base image is a bootable OCI image built `FROM` Fedora Kinoite
(atomic Fedora with Plasma).

It adds:
- the Mauvely management agent, `mauvelyd` (built in `os-agent`);
- the Mauvely Flatpak remote and its signing key;
- branding and default policy.

Devices track an image tag, which is their update ring. Updates are atomic and
roll back.

Licensed under the GNU GPL, version 3 or later.
