// Mauvely default layout (look-and-feel contents/layouts/org.kde.plasma.desktop-layout.js).
// One full-width floating panel per screen; the launcher and the tasks are centred between two
// flexible spacers, tray, clock and show-desktop on the right.
function addTaskbar(screen) {
    var panel = new Panel("org.kde.panel");
    panel.screen = screen;
    panel.location = "bottom";
    panel.height = 48;
    panel.floating = true;
    panel.lengthMode = "fill";
    panel.alignment = "center";
    panel.opacity = "translucent";
    panel.hiding = "none";

    panel.addWidget("org.kde.plasma.panelspacer");

    var kickoff = panel.addWidget("org.kde.plasma.kickoff");
    kickoff.currentConfigGroup = ["General"];
    kickoff.writeConfig("icon", "com.mauvely.start");
    kickoff.writeConfig("favoritesDisplay", 0);      // favourites as a grid
    kickoff.writeConfig("applicationsDisplay", 1);   // all apps as a list

    var tasks = panel.addWidget("org.kde.plasma.icontasks");
    tasks.currentConfigGroup = ["General"];
    tasks.writeConfig("fill", false);                // must not take the free space, or the spacers cannot centre it
    if (screen > 0) {
        tasks.writeConfig("showOnlyCurrentScreen", true);
        tasks.writeConfig("launchers", []);
    } else {
        tasks.writeConfig("launchers", ["preferred://filemanager", "preferred://browser",
            "applications:org.kde.discover.desktop", "applications:systemsettings.desktop"]);
    }

    panel.addWidget("org.kde.plasma.panelspacer");
    if (screen == 0) {
        panel.addWidget("org.kde.plasma.systemtray");
    }
    panel.addWidget("org.kde.plasma.digitalclock");
    if (screen == 0) {
        panel.addWidget("org.kde.plasma.showdesktop");
    }
}

for (var s = 0; s < screenCount; ++s) {
    addTaskbar(s);
}

var desktopsArray = desktopsForActivity(currentActivity());
for (var j = 0; j < desktopsArray.length; j++) {
    desktopsArray[j].wallpaperPlugin = "org.kde.image";
}
