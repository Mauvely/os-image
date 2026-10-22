# Handoff

## The Mauvely look in the image (brief 25, phase 2; 2026-10-22)

Commits:
- `1701d0b`: the look.
- `11af5dd`: `agent.ref` to os-agent `182f3ae`, phase 3's desktop policy.
- `89fa4f4`: the title-bar buttons as an image default; the first VM run
  showed they were missing.

Published to `next` twice:
- run 39710560414, `sha256:47c6fe18…17cfe`;
- run 39712802448, `sha256:b781a2db…a554`, which is the current `next`.

Each was booted on `mauvely-01` with a brand-new account. Phase 1's record
stays in `design/plasma/`.

### What ships, and where

| | |
|---|---|
| Global themes | `/usr/share/plasma/look-and-feel/com.mauvely.{light,dark,plasma}.desktop`: "Mauvely light", "Mauvely dark", "Plasma" |
| Colour schemes | `/usr/share/color-schemes/Mauvely{Light,Dark,Plasma}.colors` |
| Plasma style | `/usr/share/plasma/desktoptheme/mauvely` (Breeze, with translucent panel, dialogs and tooltips) |
| Wallpaper | `/usr/share/wallpapers/Mauvely` (light and dark) |
| Start glyph | `/usr/share/icons/hicolor/scalable/apps/com.mauvely.start.svg`, in the icon cache the sign-in step rebuilds |
| Fonts | `rsms-inter-fonts`, `jetbrains-mono-fonts` |
| KDE defaults | `/usr/share/mauvely/xdg/`: `kdeglobals`, `breezerc`, `kwinrc` (title-bar buttons), `kscreenlockerrc`, `kicker-extra-favoritesrc` |
| Wiring | `/etc/profile.d/mauvely-xdg.sh` |
| Window corners | `/usr/lib64/qt6/plugins/org.kde.kdecoration3/org.kde.breeze.so`, rebuilt with `patches/breeze/` |
| Login screen | `/usr/lib/plasmalogin/plasmalogin.conf.d/50-mauvely.conf` |
| Boot | `/usr/share/plymouth/themes/mauvely/`, the default in `plymouthd.defaults`; `/usr/lib/bootc/kargs.d/10-mauvely-splash.toml` (`rhgb quiet`) |

- **The Mauvely themes** are phase 1's, with three changes:
  - each has its own splash (`contents/splash/`), so the `[ksplashrc]` line
    naming Breeze's is gone;
  - their layout script also writes `breezerc` `CornerRadius=8`,
    `MenuOpacity=70` and the title-bar buttons, which a theme's `defaults`
    cannot carry (KConfig writes nothing for a value equal to the image's, so
    a new account's own files stay clean);
  - light and dark share `layoutdefaults`, `layouts/` and `splash/` byte for
    byte. The build `diff -r`s them, so change both.
- **The Plasma preset** (`com.mauvely.plasma.desktop`, phase 3's id): Breeze's
  `defaults` with:
  - `ColorScheme=MauvelyPlasma`, which is Breeze Light tinted with
    `#968ae0` by Plasma's own `plasma-apply-colorscheme --accent-color`
    (`design/plasma/src/gen_plasma_colors.sh` makes it from the base image);
  - Noto Sans written out (the image's default is Inter), `BorderSize=Normal`,
    and KWin's own buttons (`MSE` / `HIAX`), so applying it undoes
    Mauvely's;
  - Breeze's default panel, and a layout script that writes
    `CornerRadius=-1`, `MenuOpacity=100` and KWin's buttons.
  - The Containerfile copies Breeze's `splash/` and `previews/` into it. A
    global theme's splash setting only applies when the package has a splash,
    and its `defaults` name Breeze's.
- **Not set, because Breeze 6.7.5 already defaults to them**
  (`breezesettingsdata.kcfg`): centred titles (`AlignCenterFullWidth`),
  rounded corners, the outline, large shadows. `BorderSize=None` travels in
  the Mauvely themes.
- **The title-bar buttons are an image default** (`/usr/share/mauvely/xdg/kwinrc`:
  nothing on the left, `IAX` on the right), not only the themes'
  `layoutdefaults`. Plasma applies a theme's title-bar layout only with its
  desktop layout, and a first login with day/night switching applies
  appearance alone (`dayNightLookAndFeel` → `AppearanceSettings`). The first
  VM run showed KWin's window-menu button on the left; `89fa4f4` fixed it.
- **Blur** stays KWin's default: on with a GPU, off on software rendering,
  which is what the VM has.

### How the defaults beat Fedora's, and why there

- **How Fedora wires its own:**
  - `kde-settings` puts its defaults in a profile directory,
    `/usr/share/kde-settings/kde-profile/default/xdg/`. That holds the Fedora
    global theme, Noto Sans, a Kontact-first favourites list and the Fedora
    lock-screen wallpaper.
  - Its `/etc/xdg/plasma-workspace/env/env.sh` sets
    `XDG_CONFIG_DIRS=/etc/xdg:<profile>`, but only when the variable is
    empty. startplasma sources that directory's scripts, then puts
    `~/.config/kdedefaults` in front.
- **Ours:** `/etc/profile.d/mauvely-xdg.sh` sets the whole list:
  `/var/lib/mauvely-desktop/xdg:/etc/xdg:/usr/share/mauvely/xdg:<Fedora's profile>`.
  - The first entry is phase 3's policy, written by mauvelyd; it may not
    exist.
  - Fedora's env.sh then sees a value and leaves it, and startplasma still
    puts kdedefaults in front.
  - A shell inside a session (Fedora's bashrc sources profile.d too) keeps
    `…/kdedefaults:` + the list; any other value is replaced.
- **Why profile.d:** Plasma Login Manager starts both the user session and
  its own greeter through `/etc/plasmalogin/wayland-session`, which runs a
  login shell, or sources `/etc/profile` for `plasmalogin`'s nologin shell.
  So one file reaches the session and the login screen.
- **No `environment.d` entry.** The greeter never reads one, and startplasma
  copies its own `XDG_CONFIG_DIRS` into the systemd user manager anyway.
- **Why `/usr/share/mauvely/xdg`, not `/etc/xdg`:** the image's defaults
  change with each image, atomically. `/etc` is merged three ways, so a
  locally edited file there stops taking updates, and it stays the machine
  admin's layer, above the image's.
- **What a new account goes through:**
  1. startplasma reads `LookAndFeelPackage`, `AutomaticLookAndFeel` and the
     day/night pair from that list, picks light or dark, and writes the
     theme's `defaults` into `~/.config/kdedefaults`.
  2. plasmashell runs the theme's layout script once.
  - The lock-screen wallpaper and Kickoff's favourites come straight from
    `/usr/share/mauvely/xdg`.
- **Existing accounts:** any account whose own `kdeglobals` names no theme
  moves to Mauvely at its next login, without the panel layout, which only a
  new account (or a reset) gets. That is read from startplasma's source, not
  seen. timuri on the VM is unaffected: his
  phase-1 copies in `~/.local/share/plasma/look-and-feel` shadow the shipped
  themes, and his `~/.config` names them. He was left that way.

### The Breeze patch, and keeping it current

- **What the patch does:** `patches/breeze/0001-breezerc-CornerRadius.patch`
  adds `[Common] CornerRadius` (Double, logical pixels, default -1) to
  `kdecoration/breezesettingsdata.kcfg`, and uses it in
  `Decoration::setScaledCornerRadius()`. Negative keeps Breeze's own radius,
  `Frame_FrameRadius` (2.5) × the small spacing, which is 5 px on Wayland.
  KWin clips the window to it, the outline and the shadow follow it.
- **How it is built:** the `breeze-build` stage starts from the same pinned
  base (now the named stage `kinoite`; `bump-base.sh` follows the line
  `FROM … AS kinoite`).
  1. It version-locks every installed package, so `dnf builddep` pulls
     `-devel` packages at the base's exact versions; Fedora's
     `updates-archive` serves the older ones.
  2. It downloads `plasma-breeze-<base's VR>.src.rpm` from
     `fedora-source`/`updates-source` and checks it against Fedora's key with
     `rpmkeys` (`signatures OK`).
  3. It runs Fedora's `%prep`, applies `patches/breeze/*.patch` with
     `--fuzz=0`, builds only `breezedecoration` with Fedora's flags, and
     strips it.
  - The image replaces Fedora's `org.kde.breeze.so` with it and loads it with
    `RTLD_NOW` against the image's libraries. `rpm -V plasma-breeze` would
    report that one file. The KCM stays Fedora's and does not know the key.
- **It fails, loudly, when:**
  - Fedora no longer serves the base's exact source RPM (the repositories
    moved past the pin). Run `scripts/bump-base.sh`, which picks a base with
    the newer Breeze.
  - The patch no longer applies. That happens when a base bump brings a new
    Breeze, and the weekly `next` then fails and `stable` stays.
- **Refreshing the patch:**
  1. Get the new source with
     `dnf download --source plasma-breeze-<VR>` in the new base, then
     `rpm -i` it and `rpmbuild -bp` it, or check out the matching tag from
     `invent.kde.org/plasma/breeze`.
  2. Make the two changes again.
  3. Write the patch with `diff -ru a b` (paths `a/kdecoration/…`), keeping
     its header.
  4. Build. The stage's own checks say whether it applied and loads.
  - Koji's signed copies are kept for some builds only (6.7.4-2's is gone),
    so it is not a fallback.
- **Known, not fixed:** Breeze caches window shadows without the radius as a
  key. A `CornerRadius` changed while KWin runs keeps the old shadow corners
  until KWin restarts. At login the value is already there.

### Boot to desktop

- **Plymouth:** theme `mauvely` (two-step).
  - The ground is `#12142e`, the dark wallpaper's. The watermark is the
    "m." mark at 0.45 of the height, the spinner at 0.7.
  - The spinner and the unlock prompt's images are copied from Fedora's
    `spinner` theme in the Containerfile. The watermark is
    `rsvg-convert -h 112` of the splash's `mark.svg`.
  - No `Font=`: Fedora's `plymouth-populate-initrd` runs `fc-match` on the
    whole "Family Size" string, finds nothing and installs the default font
    anyway.
  - Comments in a `.plymouth` file can stop plymouth's key-file parser, so
    there are none.
  - The initramfs check now also requires the theme. 96.8 MB, unchanged.
- **`rhgb quiet`** come from bootc's kargs.d. bootc adds them at install, and
  on an update as the difference between the two images' kargs.d.
- **KSplash:** the Mauvely themes' `Splash.qml` puts the same mark and a busy
  ring where Plymouth does (`(screen − image) × alignment`), on the same
  ground.
- **Lock screen:** `kscreenlockerrc` in `/usr/share/mauvely/xdg` points it at
  the Mauvely wallpaper package, which picks the dark image with a dark
  scheme.
- **Login screen (spike):**
  - Plasma Login Manager's greeter settings are a KConfig cascade where
    `/usr/lib/plasmalogin/plasmalogin.conf.d/*` beats Fedora's
    `/usr/lib/plasmalogin/defaults.conf`, and `/etc/plasmalogin.conf` beats
    both. The cascade is `/etc/plasmalogin.conf.d/*` < `defaults.conf` <
    `/usr/lib/…/conf.d/*` < `/etc/plasmalogin.conf`; note that
    `/etc/plasmalogin.conf.d` is the lowest for the greeter, though not for
    the daemon.
  - Its keys: the wallpaper plugin and its config, `ShowClock`,
    `PreselectedUser`/`Session`. There is no colour or font key.
  - The greeter's colours, fonts and Plasma style come from the `plasmalogin`
    user's global theme. Its `startplasma-login-wayland` runs the same
    LookAndFeel/kdedefaults logic as a session, and through profile.d it
    reads Mauvely's `kdeglobals`.
  - The Login Screen KCM's "sync" writes `/var/lib/plasmalogin/.config/`,
    which wins over all of it.

### Seen on `mauvely-01` (2026-10-22, `b781a2db`, a brand-new account)

The screenshots are in the session's scratchpad (`look2/`), which is not kept.
- **The kernel command line** has `rhgb quiet`. bootc added them on the update
  from an image without kargs.d, as designed.
- **The initramfs** carries `themes/mauvely` (75 files).
- **`plymouth-set-default-theme`** prints `mauvely`. plymouthd ran from 2.2 s
  to 11 s.
- **Not seen:** the Plymouth screen itself, which a console capture over SSH
  cannot show. A composite of the shipped images at their alignments stood in.
- **`XDG_CONFIG_DIRS`** is exactly
  `…/kdedefaults:/var/lib/mauvely-desktop/xdg:/etc/xdg:/usr/share/mauvely/xdg:<Fedora's profile>`
  in plasmashell, kwin_wayland, kded6, ksmserver and System Settings.
  startplasma-wayland has the same list without kdedefaults, and so does
  timuri's session after the reboot.
- **The login screen's** startplasma-login-wayland, kwin_wayland,
  plasma-login-greeter and plasma-login-wallpaper have the same list, after
  `/var/lib/plasmalogin/.config/kdedefaults`.
- **The new account:**
  - It started on Mauvely; it was night, so dark. Every setting read back from
    its own cascade: `CornerRadius=8`, `MenuOpacity=70`, buttons ""/`IAX`,
    `BorderSize=None`, Inter 10, `MauvelyDark`, automatic switching on.
  - **Desktop and panel:** the centred taskbar with the "m." start glyph.
  - **Kickoff:** a grid of Mauvely's favourites (Firefox as the preferred
    browser, Dolphin, Konsole, System Settings, Discover, KWrite, Spectacle,
    Ark, Filelight), not Fedora's Kontact list.
  - **Dolphin:** centred title, `IAX` alone, no borders, and 8 px corners
    top and bottom. Measured against `CornerRadius=-1`, which gave Breeze's
    5 px.
  - **Lock screen:** the Mauvely wallpaper, in light and in dark.
  - **Splash:** checked with `ksplashqml --test`.
  - **Light:** forced with `knighttimerc` (`Source=Times`) and a restart of
    `plasma-knighttimed`. The switcher then put on Mauvely light within
    seconds. The file was deleted afterwards, and the switcher put back dark.
- **The Plasma preset**, applied on the first test account with
  `plasma-apply-lookandfeel -a com.mauvely.plasma.desktop --resetLayout`:
  the stock panel, the Next wallpaper, Noto Sans, the violet accent, and
  `CornerRadius=-1`/`MenuOpacity=100` in the person's `breezerc`.
- **Login screen:** the Mauvely light wallpaper behind the greeter's blur and
  dimming, Inter, the violet accent. The greeter's own global theme is
  `com.mauvely.light.desktop`: with no knighttimed in the greeter, it never
  switches to dark.
- **Afterwards:** autologin is `User=timuri` again. `mauvelytest` (uid 1001,
  no password) stays, with `Autolock=false` in its `kscreenlockerrc` so that
  an idle SSH test does not lock it. timuri's phase-1 files were left as they
  are.

### Left open

- **A screen plugged in after the first login gets no taskbar**, which is
  Plasma's behaviour. The fix would be a "Mauvely taskbar" layout template
  (`/usr/share/plasma/layout-templates/`), which also gives Add Panel a
  Mauvely choice.
- **A preset's buttons and Breeze keys travel only through its layout
  script.** KWin also picks them up only at its next reconfigure.
- **The Plasma preset keeps the Mauvely lock-screen wallpaper.** The login
  screen is always Mauvely's.
- **The Mauvely themes have no preview images**, so System Settings' Global
  Theme page shows none for them.
- **A first login at night starts light, then turns dark** about 9 s in:
  startplasma picks a theme before `plasma-knighttimed` is up, and the
  switcher corrects it. Plasma Welcome, already open by then, keeps light
  content under a dark title bar, and it greets with "Welcome to Fedora!"
  (`plasma-welcome-fedora`).
- **On the light wallpaper** the lock screen's white clock and date are faint.
  That is Breeze's lock screen; Mauvely's global themes ship none of their
  own.
- **The Plasma preset through phase 3:** `plasma-apply-lookandfeel -a`
  without `--resetLayout` brings neither the buttons nor the Breeze keys, so
  the preset keeps `IAX`, 8 px corners and acrylic menus. Phase 3 can write
  `kwinrc` and `breezerc` into its policy directory for it.
- **The two images built on `44.20261019.0`.** `bump-base.sh` finds
  `44.20261021.0` and the weekly run takes it; the Breeze stage follows by
  construction.

## The sign-in window in the image (2026-10-22)

`installer.ref` is new: the os-installer commit `mauvely-signin` is built from
(its `signin/`), the way `agent.ref` pins the agent. Both moved in this
commit: `installer.ref` to os-installer `b7436e9`, `agent.ref` to os-agent
`d4171f6`, which starts the window instead of the kdialog offer and code.
os-installer's `CLAUDE.md` ("The sign-in window") and os-agent's
`docs/broker.md` ("Linking") have the design.

- **`signin-build`**, a builder stage on Fedora 44: `qt6-qtbase-devel`,
  `qt6-qtsvg-devel`, `qt6-qtwebengine-devel`, cmake and ninja. It builds only
  `mauvely-signin` and `tst_signin` (`-DMAUVELY_SIGNIN=ON`), runs the tests,
  and installs the `signin` component into `/out`. The tests that start the
  window run with `QTWEBENGINE_DISABLE_SANDBOX=1`: a build runs as root, and
  Chromium will not start its sandbox as root. On a machine the window runs as
  the person, sandboxed.
- **In the image**: `/usr/bin/mauvely-signin`,
  `/usr/share/applications/com.mauvely.signin.desktop` (`NoDisplay=true`, the
  Wayland app id) and `/usr/share/icons/hicolor/scalable/apps/com.mauvely.signin.svg`.
  The base already has `qt6-qtwebengine` and `qt6-qtsvg`, so the only cost is
  the binary.
- **Checks in the build**: the binary is fed a bad first line and must exit 2,
  which it reaches only after every library has loaded; a builder Qt newer
  than the base's fails here, not on a machine. `desktop-file-validate`
  passes. The hicolor `icon-theme.cache` is rebuilt and must list the icon:
  ostree sets every mtime to 1970, so the base's cache would never look stale
  and the icon would not be found.
- **`scripts/build.sh`** passes `--build-context installer=…` (`INSTALLER_DIR`,
  default `../installer`) and warns when it is not at `installer.ref`.
  `build.yml` and `publish-image.yml` check out `Mauvely/os-installer` at
  `installer.ref`; it is public, so no token. `publish-image.yml` now also
  refuses to publish if os-installer is private (the image is GPL and built
  from it).

**Built locally, not booted, not pushed:** `localhost/mauvely-os:signin`,
`935d94b77966`, 7.58 GB, from clean checkouts of os-agent `d4171f6` and
os-installer `b7436e9` (`JOBS=24`). `installer.ref` is `900fb48`, which
changes only os-installer's `CLAUDE.md` and `HANDOFF.md`; neither is copied
into the image. In the build: `tst_signin` 21 passed on Fedora 44's Qt 6.11.2,
the loader check exited 2, `desktop-file-validate` passed, the icon cache
lists the icon, and `bootc container lint` passed 14 checks and skipped 1.
`/usr/bin/mauvely-signin` is 1.6 MB.

**For the real run on `mauvely-01`** (Timur's): publish to `next`, let the VM
take it, and log in to Plasma as a local user with no `os.cred`. The window
should open by itself with the code; signing in and approving should end in
"Signed in to Mauvely as …". Worth watching there, none of it seen yet: KWin's
placement and focus for a window a user service starts, the window's icon in
the task manager, the OpenURI portal handing "Use your browser instead" and
off-site links to the browser Flatpak, and the light and dark schemes
switching while the window is open.

**Worth knowing:** the builder stage adds Qt WebEngine's devel packages, a few
hundred MB, on GitHub-hosted runners where `build.yml` already clears space
for the 7.4 GB base. `build.yml` has not run with it.

## The Mauvely look, phase 1 (brief 25; prototype in `design/plasma/`)

Prototyped live on the VM on 2026-10-21. Timur's decisions: day/night
switching, Inter, re-apply on change, and two locks (the look; the panel and
widgets). Phase 2 shipped it: the section above says what changed on the way.

**Settings that phase 2 must reproduce:**
- **Window decoration:**
  - kwinrc `[org.kde.kdecoration2]`: `library=org.kde.breeze`,
    `BorderSize=None`, `BorderSizeAuto=false`, `ButtonsOnLeft=`,
    `ButtonsOnRight=IAX`;
  - breezerc: `[Windeco] TitleAlignment=AlignCenterFullWidth`,
    `[Common] RoundedCorners=true`, `OutlineEnabled=true`,
    `ShadowSize=ShadowLarge`, `[Style] MenuOpacity=70`.
- **Day and night:** kdeglobals `[KDE] AutomaticLookAndFeel=true`,
  `DefaultLightLookAndFeel=com.mauvely.light.desktop`,
  `DefaultDarkLookAndFeel=com.mauvely.dark.desktop`. The schedule is
  `knighttimerc`, which defaults to the location.
- **Fonts, in each theme's defaults:** Inter 10 for `font`, `menuFont` and
  `toolBarFont`; Inter 8 for `smallestReadableFont`; JetBrains Mono 10 for
  `fixed`; Inter 600 for `[WM] activeFont`.
  - A Plasma 6.7 bug also needs `[kdeglobals][WM] font=`: the theme loader
    looks for the font keys in the wrong group.
- **The panel** (`layouts/org.kde.plasma.desktop-layout.js`): one per screen,
  `lengthMode=fill`, floating, 48 px, translucent. In order: spacer, Kickoff
  (grid favourites, `icon=com.mauvely.start`), icon tasks with `fill=false`,
  spacer, tray, clock, show-desktop.
- **Blur:**
  - the Plasma style "mauvely" falls back to Breeze, except
    `dialogs/background`, `widgets/panel-background` and `widgets/tooltip` at
    0.7 opacity;
  - kwinrc `[Plugins] blurEnabled=true` is needed only on software rendering.

**Spikes:**
- **Corners: use Breeze's own** (`RoundedCorners`, all four corners once
  borders are off). The radius is fixed at ~5 px; Windows 11 is 8 px.
  - Aurorae can't round the window's content.
  - KDE-Rounded-Corners breaks with every KWin update, and the base moves
    weekly.
- **Taskbar: spacers in one full-width panel.** Fit-content docks overlapped
  the tray at 1280×800. A screen plugged in after the first login gets no
  panel; phase 2 decides that.

**Phase 2 must also:**
- Override Fedora's `/usr/share/kde-settings/kde-profile/default/xdg/`
  defaults (`kicker-extra-favoritesrc` with `IgnoreDefaults=true`, Noto Sans,
  the Fedora global theme, the lock-screen wallpaper). Ship the image's own.
- Add the packages `rsms-inter-fonts` and `jetbrains-mono-fonts`.

**Spikes 3 and 4 (the admin lock):**
- Plasma 6 has no "lock widgets" a person can't lift. Scripting
  `panel.locked` is undone by them. An admin lock needs Kiosk `[$i]`, or
  `[KDE Action Restrictions] plasma/plasmashell/unlockedDesktop=false`.
  Neither tried.
- `~/.config/kdedefaults/` sits first in `XDG_CONFIG_DIRS`, so a policy
  directory added later needs `[$i]` to win.

## The sign-in broker in the image (brief 22, S2; 2026-10-21)

`agent.ref` is os-agent `c6e1d21`: `mauvely-session` now carries the sign-in
broker (os-agent `docs/broker.md`), reviewed adversarially and fixed.
`rootfs/usr/share/user-tmpfiles.d/mauvely.conf` makes `$XDG_RUNTIME_DIR/mauvely`
(0700) at login, because Flatpak shares `xdg-run/mauvely` into an app only if
it exists when the app starts. `systemd-creds.socket` is active on the image
already (sockets.target), and a same-user `systemd-creds --user` round trip
works on the VM. Built and linted locally; never booted. Linking for real
needs Timur: a Plasma login on a machine on `next`, and approving the code in
his own signed-in browser.

## /boot was too small for an update (2026-10-21, Timur's Proxmox VM)

**Every installed machine could never take an image update with a new
kernel.** bootc's `to-disk` makes a 510 MB `/boot` (446 MB usable), Kinoite's
generic initramfs is 238 MB (NVIDIA firmware alone is 104 MB), so a kernel
set is ~257 MB and two never fit. The VM's move to `next` (7.2.9 → 7.2.11)
failed at shutdown with "Installing kernel: regfile copy: No space left on
device", and the agent staged it again every boot.

- **Fix:** `rootfs/usr/lib/dracut/dracut.conf.d/90-mauvely-initramfs.conf`
  drops the NVIDIA and AMD display drivers (and so their firmware) from the
  initramfs; the Containerfile rebuilds it. 96.8 MB. On those machines the
  splash and the recovery prompt use simpledrm until the real driver loads
  from the root filesystem.
- **The trap, hit once:** a plain `dracut` leaves out the `ostree` module that
  Fedora's compose adds with `--add ostree`. The initramfs then unlocks the
  disk and fails at "Switch Root" into emergency mode. The config adds the
  module, and the build fails without it (`lsinitrd -m | grep -qx ostree`) or
  past 150 MB.
- **Proven on the VM** (local build `slim3` from a LAN registry, agent
  masked): the switch from the 257 MB set finalised at shutdown with both sets
  in `/boot` (402 of 446 MB), the next boot unlocked from the TPM with no
  prompt, no unit failed, tuned and tuned-ppd ran. Not tried: real NVIDIA or
  AMD hardware, Secure Boot changes that need the recovery prompt.
- **Recovering a machine stuck on a bad deployment:** hold F8 at boot for
  GRUB's menu and pick `ostree:1`.
- **Not done:** a bigger `/boot` for new installs. bootc's `to-disk` has no
  option for it, so it would mean the installer partitioning itself and
  using `to-filesystem`.

## Brief 22, U2: mauvely-session in the image (2026-10-16)

- **`agent.ref` → os-agent `d279540`** (`d52c86f`, plus a fix: a staged deployment of the booted image, as mauvely-seal makes, is not announced). mauvelyd now updates system Flatpaks
  (at most every 6 h) and discards a staged image the server no longer wants
  (`rpm-ostree cleanup --pending`). os-agent's `HANDOFF.md` has the detail and
  what has never run.
- **`mauvely-session`** is installed at `/usr/bin/mauvely-session`, with its user
  unit in `/usr/lib/systemd/user/` and `systemctl --global enable`d into
  `graphical-session.target`. It shows "Restart to finish updating" once per
  staged deployment. `rpm-ostree` stays: the agent and the session both call it.
- **Built locally** (`localhost/mauvely-os:u2`, lint 14 checks) from a clean
  export of `d52c86f`: both binaries present, both units enabled.
- **Not run on a booted system.** The first `next` that carries it is the first
  test, on Timur's Proxmox VM.

## From Timur's first install on Proxmox (2026-10-16), not done yet

He asked for these to be noted, not done:
- ~~**Boot is text, not a splash.**~~ Done in brief 25's phase 2 (above):
  `kargs.d` gives `rhgb quiet`, and the Plymouth theme is Mauvely's.
- **The installer's copy step looks stuck** (os-installer): bootc prints nothing
  between "layers needed: 266 (7.5 GB)" and the end. Show the bytes written to
  the target disk instead.

## Brief 22, U1: updates (2026-10-16)

Brief 22 is `Website/website-internal/docs/launch/plans/22-os-updates-sso-vault.md`.
- **The weekly `next`** (Timur's decision). `publish-image.yml` gains a Monday
  schedule. Its `bump` job runs `scripts/bump-base.sh`, which moves the Kinoite
  pin to Fedora's newest `44.<date>.<n>` build. The job commits the bump to
  `main` as github-actions, and `publish` builds that commit as `next`. A week
  with no newer base publishes nothing, and the schedule never touches
  `stable`. A dispatch works as before.
  - Linted with actionlint 1.7.7.
  - `bump-base.sh` was run against quay: it moved 44.20261013.0 to
    44.20261016.0, then printed nothing on a second run. The pin was put back,
    so the first schedule makes that move.
  - **The schedule has never run.** Its first run is the next Monday, 04:17 UTC.
- **Nothing else updates the system:**
  - `plasma-discover-rpm-ostree` is removed;
  - Discover's `UseUnattendedUpdates=false`;
  - `rpm-ostree-countme` (timer and service) is masked.
  - The polkit rule letting any active user run `rpm-ostree upgrade` is
    untouched. Without Discover's backend that takes a terminal, and M2's users
    are not admins.
- **Built locally** (`localhost/mauvely-os:u1`, lint 14 checks): the backend is
  gone, the setting reads `false`, both countme units are `masked`.
- **Left open:** Discover's `fwupd` backend can still apply firmware updates,
  including `dbx`. A `dbx` change moves PCR 7, so the next boot asks for the
  recovery key. That belongs with M3's re-seal.
- **Rechunking: measured, not done.** The Kinoite base is already split into
  257 layers by Fedora. From 13 to 14 October, 49 of them changed: 902 MB of
  3,106 MB compressed. From 13 to 16 October, 53 changed: 921 MB. One 281 MB
  layer changes in every build. Rechunking this image cannot shrink the base's
  own churn, so a weekly update downloads about 1 GB.

P5 of brief 19 ran on 2026-10-14: the real image, the build CI and the Flatpak
publishing. The image was built, installed to a blank disk under Secure Boot and
a TPM, rebooted and checked. `build.yml` has run once on GitHub, on the push of
this work: with no `OS_AGENT_TOKEN` it took 6 s, wrote the warning and the summary,
and ended green (run 38500193127). **The build itself has never run there**, the
publish workflow has never run at all, and nothing was published or pushed to any
registry.

## P7, the end-to-end demo (2026-10-14)

**P7 passed** on P5's image, through os-installer's test ISO, against a
local website-devices and website-enterprise. The stages were:
- install;
- enrol by token;
- four apps from the collection: Compose from a local mauvely remote, the
  others from Flathub;
- one app unassigned and removed;
- revoke, then 403.

`proof/p7/README.md` has the setup, the timeline, and what the run did not
show.


## T4, the registry (2026-10-14: done, `stable` published)

**Timur decided:**
- public GHCR at `ghcr.io/mauvely/os`, with two tags, `stable` and `next`;
- cosign-signed, and the image's own policy requires the signature;
- the registry can move later through website-devices' `OS_IMAGE_REPO`.
  `registry.mauvely.com` on R2 is the later option.

**Merged with the key.** Timur made the key pair, which created the
`COSIGN_*` secrets, and all three OS repositories are public. `build.yml` then
built the whole image on GitHub for the first time, including the agent and
the lint: run 38566709935, 5 minutes, green.

**What the branch adds:**
- `policy.json` gains one `sigstoreSigned` rule for `ghcr.io/mauvely/os`, with
  the key at `/etc/pki/containers/mauvely-os.pub`.
- `registries.d/mauvely-os.yaml` turns on sigstore attachments for that
  repository. Every other registry keeps the base's accept-anything default.
- `publish-image.yml`, dispatched by hand. Its header says what each channel
  does and what it refuses to run without.
- `scripts/test-image-policy.sh`.
- `agent.ref` moves to `09b2536`. The agent now runs `bootc upgrade` when the
  booted image is the one wanted, so a device on `stable` takes a newer
  stable. Before this, nothing ever upgraded within a tag.

**Shown:**
- **On real bootc** (`proof/t4/`), in an overlay of P5's VM:
  - an unsigned image and a wrong-key image are refused by `bootc switch` and
    by `bootc upgrade`, with the default transport and no flag;
  - a signed image is accepted;
  - `bootc upgrade` stages a newer signed build under the same tag.
- **`test-image-policy.sh`** shows the same with skopeo. It also shows that
  cosign v3's default format is invisible to devices, which is why the
  workflow pins v2.

**Never run:**
- **`/etc` keeps a locally edited `policy.json` whole** across updates
  (`proof/t4/`). A future key rotation reaches only devices whose file is
  untouched.
- **Discover and `rpm-ostree upgrade`** (below) pull through the same policy,
  so they too can stage only a signed image.

**The first publish, in order:**
1. ~~The key pair~~, done 2026-10-14.
2. ~~os-agent and os-image public~~, done 2026-10-14.
3. ~~Dispatch `publish-image.yml` with `next`~~: run 38567573684, green.
   `ghcr.io/mauvely/os:next` is `sha256:ccf06254…7e88`, signed (Rekor entry
   3250603642), and the run's pull-back through the image's own policy passed.
4. ~~Make the GHCR package public~~: done; an anonymous manifest read answers 200.
5. ~~website-devices' `OS_IMAGE_REPO`~~ is `ghcr.io/mauvely/os`, on staging
   and production (website-devices `3a89f2c`).
6. ~~Check in a VM~~: enrolled against staging, it switched to `next`, booted
   it, then staged a second `next` (`46945ca1…`) through the real key, and
   refused it under a throwaway key (`proof/t4/`, "On GHCR").
8. ~~`stable`~~: run 38575339843, green. `:stable` and `:next` are both
   `sha256:46945ca1…6650`, the build the VM staged.
7. ~~The installer's target ref~~: `ghcr.io/mauvely/os:stable`, os-installer
   `7218b1b`.

The machines from P5–P7 report `registry.invalid/…`. Their first switch to
GHCR pulls without a check, because their own image has no policy yet.
After that, the policy holds.

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
  staging values.
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
  An update pulls only changed layers (measured above, under brief 22).

## What Plasma Discover did with OS updates (closed by brief 22, U1, above)

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

- ~~**R2 secrets and the domain.**~~ Done 2026-10-14: all four secrets are
  set, and `flatpak.mauvely.com` is the bucket's custom domain.
  The first publish ran the same day (below).
- ~~**T4's first publish**~~ Done 2026-10-14: `next` and `stable` are
  published, signed and public.
- **The remote is live, with one wrong ref in it.** Timur dispatched
  `publish-flatpak.yml` on 2026-10-14 at 18:49 UTC (run 38618413513), before
  Compose 0.5.4 was in the feed and before the id check existed. A client
  holding `keys/mauvely-flatpak.gpg` now lists `com.mauvely.sotto//stable`
  (Sotto 0.1.1, right) and `net.mauvely.compose.app//stable` (Compose 0.5.3
  from August, under the id from before plan 20). No device is assigned that
  id, so nothing installs it.
  - **The next dispatch removes it.** `publish-flatpak.sh` deletes any
    `app/net.mauvely.*` ref and the workflow syncs `refs/` up with `--delete`
    (`f80f287` added the id check; the removal is the commit after). Tried on
    a mirror of the live remote with a throwaway key: `apps: sotto` removed
    the Compose ref, left Sotto unchanged, and the summary named Sotto alone.
    The R2 `--delete` itself has not run anywhere.
  - Dispatching with `apps: sotto` now cleans it up today. With the default
    `compose sotto` it fails on Compose until 0.5.4 is in the feed, because
    the feed's newest Compose Flatpak is still 0.5.3's.
  - **Compose 0.5.4's release failed at registration with a 401.** Compose's
    repo secret `MAUVELY_RELEASES_TOKEN` (set 2026-07-30) overrides the org's
    and is stale. Once it is fixed and the run re-run,
    `curl -s "https://mauvely.com/api/releases?app=compose"` shows a `flatpak`
    item for 0.5.4, and a `compose sotto` dispatch publishes
    `com.mauvely.compose`. `scripts/test-publish-flatpak.sh` reads the live
    feed, so try it first.
- ~~**Flathub for the runtime.**~~ Fixed 2026-10-14 in website-devices
  `8e935a8`, on staging and production: the plane sends Flathub whenever a
  Mauvely app is assigned. The bundles name it as their `--runtime-repo`, and
  `org.kde.Platform` comes from there, not from the Mauvely remote. P7 never
  saw it because Firefox brought Flathub along.

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
