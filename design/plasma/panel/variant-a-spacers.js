// Mauvely panel, variant A: one full-width floating panel. The launcher and the tasks sit
// between two flexible spacers, which Plasma sizes so the group is centred on the panel;
// tray, clock and show-desktop sit on the right.
var old = panels();
for (var i = 0; i < old.length; ++i) { old[i].remove(); }

var panel = new Panel("org.kde.panel");
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
kickoff.writeConfig("favorites", ["preferred://browser", "org.kde.dolphin.desktop", "org.kde.konsole.desktop",
    "systemsettings.desktop", "org.kde.discover.desktop", "org.kde.kwrite.desktop", "org.kde.spectacle.desktop",
    "org.kde.ark.desktop", "org.kde.filelight.desktop"]);

var tasks = panel.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("fill", false);                // must not take the free space, or the spacers cannot centre it
tasks.writeConfig("launchers", ["preferred://filemanager", "preferred://browser",
    "applications:org.kde.discover.desktop", "applications:systemsettings.desktop"]);

panel.addWidget("org.kde.plasma.panelspacer");
panel.addWidget("org.kde.plasma.systemtray");
panel.addWidget("org.kde.plasma.digitalclock");
panel.addWidget("org.kde.plasma.showdesktop");
