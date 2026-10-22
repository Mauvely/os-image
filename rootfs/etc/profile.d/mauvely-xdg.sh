# Mauvely OS: where KDE finds its defaults, highest first (brief 25). Every login
# shell reads this, and so do Plasma sessions and the Plasma Login Manager
# greeter, which start through one (/etc/plasmalogin/wayland-session).
# startplasma then puts ~/.config/kdedefaults in front.
#   /var/lib/mauvely-desktop/xdg   the admin's policy, written by mauvelyd; may not exist
#   /etc/xdg                       this machine's own
#   /usr/share/mauvely/xdg         the image's defaults: the Mauvely look
#   Fedora's kde-settings profile, which /etc/xdg/plasma-workspace/env/env.sh
#                                  would otherwise make the whole list
# A shell inside a session keeps its kdedefaults in front; any other value is
# replaced.
mauvely_xdg=/var/lib/mauvely-desktop/xdg:/etc/xdg:/usr/share/mauvely/xdg:/usr/share/kde-settings/kde-profile/default/xdg
case "${XDG_CONFIG_DIRS-}" in
    "$mauvely_xdg" | */kdedefaults:"$mauvely_xdg") ;;
    *) XDG_CONFIG_DIRS=$mauvely_xdg ;;
esac
export XDG_CONFIG_DIRS
unset mauvely_xdg
