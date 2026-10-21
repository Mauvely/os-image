#!/bin/bash
# Put the person's Plasma back as it was before the Mauvely prototype (backup taken 2026-10-21 23:27).
# Run as timuri inside the Plasma session (or over SSH with the session's environment set).
set -e
B=~/mauvely-prototype-backup

# 1. Stop the day/night switcher first, or it re-applies Mauvely at the next sunrise or sunset.
kwriteconfig6 --file kdeglobals --group KDE --key AutomaticLookAndFeel false --notify
# 2. Re-apply the original global theme so running apps get its colours, icons and fonts live.
plasma-apply-lookandfeel -a org.fedoraproject.fedoradark.desktop >/dev/null 2>&1 || true
# 3. Put the backed-up files back with the shell stopped, or it writes its panels over them on exit.
systemctl --user stop plasma-plasmashell.service
for f in kdeglobals kwinrc plasma-org.kde.plasma.desktop-appletsrc plasmashellrc kscreenlockerrc; do
  cp -a "$B/$f" ~/.config/"$f"
done
rm -rf ~/.config/kdedefaults && cp -a "$B/kdedefaults" ~/.config/kdedefaults
# these did not exist before the prototype
rm -f ~/.config/breezerc ~/.config/plasmarc ~/.config/ksplashrc ~/.config/kcminputrc \
      ~/.config/knighttimerc ~/.config/kicker-extra-favoritesrc
# 4. The prototype's own files. Inter and JetBrains Mono stay installed; to remove them too:
#    rm -rf ~/.local/share/fonts/rsms-inter-fonts ~/.local/share/fonts/jetbrains-mono-fonts && fc-cache -f
rm -rf ~/.local/share/color-schemes/MauvelyLight.colors ~/.local/share/color-schemes/MauvelyDark.colors \
       ~/.local/share/plasma/desktoptheme/mauvely \
       ~/.local/share/plasma/look-and-feel/com.mauvely.light.desktop ~/.local/share/plasma/look-and-feel/com.mauvely.dark.desktop \
       ~/.local/share/wallpapers/Mauvely ~/.local/share/icons/hicolor/scalable/apps/com.mauvely.start.svg
# 5. Reload.
qdbus-qt6 org.kde.KWin /KWin reconfigure || true
qdbus-qt6 org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect blur || true
systemctl --user start plasma-plasmashell.service
echo "Restored. Log out and back in so every app reads the old fonts and colours from the start."
