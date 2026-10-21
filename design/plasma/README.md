# The Mauvely look: phase 1 prototype (brief 25)

What was live on Timur's development VM on 2026-10-21. It is a working record
for phase 2, which turns it into look-and-feel packages in the image. Nothing
here is in the image yet.

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
