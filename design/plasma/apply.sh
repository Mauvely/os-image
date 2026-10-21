#!/bin/bash
# Apply the Mauvely prototype look to the person's running Plasma session (Plasma 6.7).
# Run as the person, inside the session (or over SSH with the session's environment set).
# Installs nothing system-wide: everything goes under ~/.local/share and ~/.config.
set -e
H=$(cd "$(dirname "$0")" && pwd)
L=~/.local/share

# 0. Fonts: Inter and JetBrains Mono from Fedora 44's own repository, signature-checked, unpacked per user.
if ! fc-list | grep -q '/Inter-Regular'; then
  D=$(mktemp -d); B=https://dl.fedoraproject.org/pub/fedora/linux/releases/44/Everything/x86_64/os/Packages
  ( cd "$D"
    curl -sfO $B/r/rsms-inter-fonts-4.1-3.fc44.noarch.rpm
    curl -sfO $B/j/jetbrains-mono-fonts-2.304-10.fc44.noarch.rpm
    rpmkeys --dbpath "$D" --import /etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-44-primary
    rpmkeys --dbpath "$D" -K *.rpm
    for r in *.rpm; do rpm2cpio "$r" | cpio -idm --quiet './usr/share/fonts/*'; done
    mkdir -p "$L/fonts" && cp -r usr/share/fonts/rsms-inter-fonts usr/share/fonts/jetbrains-mono-fonts "$L/fonts/" )
  rm -rf "$D"; fc-cache -f "$L/fonts"
fi

# 1. Colour schemes, Plasma style, global themes, wallpaper, launcher icon.
mkdir -p $L/color-schemes $L/plasma/desktoptheme $L/plasma/look-and-feel $L/wallpapers $L/icons/hicolor/scalable/apps
cp "$H"/color-schemes/*.colors $L/color-schemes/
cp -r "$H"/plasma/desktoptheme/mauvely $L/plasma/desktoptheme/
cp -r "$H"/plasma/look-and-feel/com.mauvely.light.desktop "$H"/plasma/look-and-feel/com.mauvely.dark.desktop $L/plasma/look-and-feel/
cp -r "$H"/wallpapers/Mauvely $L/wallpapers/
cp "$H"/icons/hicolor/scalable/apps/com.mauvely.start.svg $L/icons/hicolor/scalable/apps/

# 2. Window decoration: Breeze, no borders, centred title, minimise/maximise/close on the right,
#    every corner rounded (Breeze's own option; KWin clips the window to it).
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library org.kde.breeze
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme Breeze
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key BorderSize None
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key BorderSizeAuto false
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnLeft ""
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnRight IAX
kwriteconfig6 --file breezerc --group Windeco --key TitleAlignment AlignCenterFullWidth
kwriteconfig6 --file breezerc --group Common --key RoundedCorners true
kwriteconfig6 --file breezerc --group Common --key OutlineEnabled true
kwriteconfig6 --file breezerc --group Common --key ShadowSize ShadowLarge
# 3. Acrylic menus in Qt apps (Breeze style), and KWin's blur. Blur is on by default on a real GPU;
#    this VM renders with llvmpipe, where KWin leaves it off unless asked.
kwriteconfig6 --file breezerc --group Style --key MenuOpacity 70
kwriteconfig6 --file kwinrc --group Plugins --key blurEnabled true

# 4. The global theme, with its panel layout (layouts/org.kde.plasma.desktop-layout.js).
plasma-apply-lookandfeel -a com.mauvely.light.desktop --resetLayout

# 5. Light by day, dark by night (Plasma's own switcher, kded "lookandfeelautoswitcher";
#    the schedule comes from knighttimed: by default sunrise/sunset at the automatic location).
kwriteconfig6 --file kdeglobals --group KDE --key DefaultLightLookAndFeel com.mauvely.light.desktop --notify
kwriteconfig6 --file kdeglobals --group KDE --key DefaultDarkLookAndFeel com.mauvely.dark.desktop --notify
kwriteconfig6 --file kdeglobals --group KDE --key AutomaticLookAndFeel true --notify

# 6. Reload KWin and the shell so the decoration, blur, Plasma style and menu opacity take effect.
qdbus-qt6 org.kde.KWin /KWin reconfigure
qdbus-qt6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect blur >/dev/null
systemctl --user restart plasma-plasmashell.service
echo "Mauvely applied. Apps started before this pick up the new fonts when they restart."
