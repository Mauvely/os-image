// Mauvely panel, variant B: two "fit content" floating panels on the bottom edge.
// A centred island holds the launcher and the tasks; a right-aligned island holds tray, clock and show-desktop.
var old = panels();
for (var i = 0; i < old.length; ++i) { old[i].remove(); }

var dock = new Panel("org.kde.panel");
dock.location = "bottom";
dock.height = 48;
dock.floating = true;
dock.lengthMode = "fit";
dock.alignment = "center";
dock.opacity = "translucent";
dock.hiding = "none";

var kickoff = dock.addWidget("org.kde.plasma.kickoff");
kickoff.currentConfigGroup = ["General"];
kickoff.writeConfig("icon", "com.mauvely.start");
kickoff.writeConfig("favoritesDisplay", 0);
kickoff.writeConfig("applicationsDisplay", 1);
kickoff.writeConfig("favorites", ["preferred://browser", "org.kde.dolphin.desktop", "org.kde.konsole.desktop",
    "systemsettings.desktop", "org.kde.discover.desktop", "org.kde.kwrite.desktop", "org.kde.spectacle.desktop",
    "org.kde.ark.desktop", "org.kde.filelight.desktop"]);

var tasks = dock.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("fill", false);
tasks.writeConfig("launchers", ["preferred://filemanager", "preferred://browser",
    "applications:org.kde.discover.desktop", "applications:systemsettings.desktop"]);

var tray = new Panel("org.kde.panel");
tray.location = "bottom";
tray.height = 48;
tray.floating = true;
tray.lengthMode = "fit";
tray.alignment = "right";
tray.opacity = "translucent";
tray.hiding = "none";
tray.addWidget("org.kde.plasma.systemtray");
tray.addWidget("org.kde.plasma.digitalclock");
tray.addWidget("org.kde.plasma.showdesktop");
