// Variant A on an extra screen: the same centred taskbar, showing only that screen's windows.
// Plasma gives a new screen a desktop but no panel, so this has to run per screen (screen 1 here).
var panel = new Panel("org.kde.panel");
panel.screen = 1;
panel.location = "bottom";
panel.height = 48;
panel.floating = true;
panel.lengthMode = "fill";
panel.alignment = "center";
panel.opacity = "translucent";
panel.addWidget("org.kde.plasma.panelspacer");
var kickoff = panel.addWidget("org.kde.plasma.kickoff");
kickoff.currentConfigGroup = ["General"];
kickoff.writeConfig("icon", "com.mauvely.start");
var tasks = panel.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("fill", false);
tasks.writeConfig("showOnlyCurrentScreen", true);
tasks.writeConfig("launchers", []);
panel.addWidget("org.kde.plasma.panelspacer");
panel.addWidget("org.kde.plasma.digitalclock");
