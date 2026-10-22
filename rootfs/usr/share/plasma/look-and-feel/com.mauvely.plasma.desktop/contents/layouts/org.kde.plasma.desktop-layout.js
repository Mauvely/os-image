// Plasma's own layout, as Breeze's global theme has it.
loadTemplate("org.kde.plasma.desktop.defaultPanel")

var desktopsArray = desktopsForActivity(currentActivity());
for (var j = 0; j < desktopsArray.length; j++) {
    desktopsArray[j].wallpaperPlugin = "org.kde.image";
}

// Breeze as KDE ships it: its own corner radius (CornerRadius is os-image's patches/breeze/;
// negative is Breeze's own) and opaque menus, over the image's Mauvely defaults.
var breeze = ConfigFile("breezerc", "Common");
breeze.writeEntry("CornerRadius", -1);
breeze.group = "Style";
breeze.writeEntry("MenuOpacity", 100);
