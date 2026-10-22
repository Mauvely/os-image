# The Mauvely look: phase 1 prototype (brief 25)

What was live on Timur's development VM on 2026-10-21, kept as the record of
phase 1. **Phase 2 shipped it in the image on 2026-10-22**: the shipped files
are under `rootfs/` (`usr/share/plasma/look-and-feel/com.mauvely.*`, the colour
schemes, the Plasma style, the wallpaper, the KDE defaults in
`usr/share/mauvely/xdg`) and `patches/breeze/`, and they move on from here;
this directory does not follow them. os-image's `HANDOFF.md` says what changed
on the way.

- **What it is:**
  - Mauvely light and dark global themes, switched by time of day;
  - a centred, floating, full-width taskbar (spacers);
  - Breeze with centred titles, no borders and rounded corners;
  - a translucent Plasma style over KWin's blur;
  - Inter and JetBrains Mono;
  - a placeholder wallpaper.
- **`apply.sh`** puts the look on a Plasma 6.7 session from scratch, all under
  `~/.local/share` and `~/.config`. **`restore.sh`** puts a backed-up desktop
  back.
- **Every setting, and the two spikes** (Breeze's own corners rather than
  Aurorae or a KWin effect; spacers rather than fit-content panels), are in
  os-image's `HANDOFF.md`.

Inter and JetBrains Mono came from Fedora 44's repository, signature-checked.
In the image they are the `rsms-inter-fonts` and `jetbrains-mono-fonts`
packages.
