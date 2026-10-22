# Mauvely OS: the image (brief 19, P5). The pinned Kinoite base, the device agent,
# the sign-in window, one first-boot unit for the disk, and the removals that
# keep a machine's apps and updates in the management plane's hands.
#
# Build it with scripts/build.sh, which supplies the `agent` and `installer`
# named contexts and warns when either checkout is not the commit pinned in
# agent.ref or installer.ref.

# ── the base ─────────────────────────────────────────────────────────────────
# The tag is pinned to a dated build, never `latest` or a bare release number.
# publish-image.yml's weekly run moves it to Fedora's newest 44 build
# (scripts/bump-base.sh, which looks for this one line). Moving to 45 is a
# deliberate commit; it is still in Beta. The Breeze stage and the image both
# start from it.
FROM quay.io/fedora-ostree-desktops/kinoite:44.20261019.0 AS kinoite

# ── mauvelyd ─────────────────────────────────────────────────────────────────
# Built on Fedora 44, the base's own release, so the binary links the same glibc.
# A binary from the host needs a newer one and does not start.
FROM quay.io/fedora/fedora:44 AS agent-build
ARG CARGO_BUILD_JOBS=8
RUN dnf -y install --setopt=install_weak_deps=False cargo gcc && dnf clean all
WORKDIR /src
# Named paths, not the whole context: a local checkout carries a target/ of
# several gigabytes.
COPY --from=agent Cargo.toml Cargo.lock ./
COPY --from=agent crates ./crates
COPY --from=agent tests ./tests
RUN cargo build --release --locked

# ── mauvely-signin ───────────────────────────────────────────────────────────
# The sign-in window mauvely-session starts (os-installer's signin/). Built on
# Fedora 44 against its Qt, which is the base's: the check after the copy below
# fails the build if this Qt is newer than the one the image runs.
FROM quay.io/fedora/fedora:44 AS signin-build
ARG CMAKE_BUILD_PARALLEL_LEVEL=8
RUN dnf -y install --setopt=install_weak_deps=False \
      cmake ninja-build gcc-c++ qt6-qtbase-devel qt6-qtsvg-devel qt6-qtwebengine-devel \
 && dnf clean all
WORKDIR /src
# Named paths, not the whole context: proof/ holds the installer's screenshots.
COPY --from=installer CMakeLists.txt ./
COPY --from=installer src ./src
COPY --from=installer resources ./resources
COPY --from=installer signin ./signin
COPY --from=installer tests ./tests
# Only the window and its tests: the installer's own targets are not built.
# The build runs as root, and Chromium will not start its sandbox as root, so the
# tests that start the window run without it here. On a machine it runs as the
# person, sandboxed.
RUN cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DMAUVELY_SIGNIN=ON \
 && cmake --build build --target mauvely-signin tst_signin \
 && QT_QPA_PLATFORM=offscreen QTWEBENGINE_DISABLE_SANDBOX=1 build/bin/tst_signin \
 && DESTDIR=/out cmake --install build --component signin

# ── Breeze's window decoration, with a corner radius ─────────────────────────
# Breeze rounds windows at 5 px and has no setting for it. patches/breeze/ adds
# breezerc [Common] CornerRadius (logical pixels; Breeze's own when unset), and
# the image sets 8 (brief 25). This stage builds only the decoration plugin,
# from Fedora's signed source RPM of the plasma-breeze in the base, against the
# base's own libraries: every installed package is version-locked first, so
# the build dependencies come at the base's versions (updates-archive keeps
# the older ones). It fails, rather than build something else, when Fedora no
# longer serves that source or the patch no longer applies; HANDOFF.md says
# how to refresh the patch.
FROM kinoite AS breeze-build
ARG CMAKE_BUILD_PARALLEL_LEVEL=8
COPY patches/breeze/ /patches/
RUN vr="$(rpm -q --qf '%{VERSION}-%{RELEASE}' plasma-breeze)" \
 && dnf -q versionlock add $(rpm -qa --qf '%{NAME}\n' | sort -u) >/dev/null \
 && dnf -y install --setopt=install_weak_deps=False rpm-build ninja-build \
 && mkdir -p /src && cd /src \
 && { dnf download --source --enablerepo=fedora-source --enablerepo=updates-source "plasma-breeze-$vr" \
      || { echo "breeze-build: Fedora no longer serves the source of plasma-breeze-$vr; move the base (scripts/bump-base.sh)" >&2; exit 1; }; } \
 && rpmkeys --dbpath /src/keys --import "/etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-$(rpm -E %fedora)-primary" \
 && rpmkeys --dbpath /src/keys --checksig "plasma-breeze-$vr.src.rpm" | grep -q 'signatures OK' \
 && rpm -i --define '_topdir /src/rpmbuild' "plasma-breeze-$vr.src.rpm" \
 && dnf -y builddep --setopt=install_weak_deps=False --without kf5 /src/rpmbuild/SPECS/plasma-breeze.spec \
 && rpmbuild --define '_topdir /src/rpmbuild' --without kf5 -bp /src/rpmbuild/SPECS/plasma-breeze.spec \
 && cd "$(find /src/rpmbuild/BUILD -maxdepth 2 -type d -name "breeze-${vr%-*}")" \
 && for p in /patches/*.patch; do \
      patch -p1 --forward --batch --fuzz=0 < "$p" \
        || { echo "breeze-build: $p no longer applies to plasma-breeze-$vr; refresh it (HANDOFF.md)" >&2; exit 1; }; \
    done \
 && eval "$(rpm -E '%{set_build_flags}')" \
 && cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_INSTALL_PREFIX=/usr \
      -DKDE_INSTALL_USE_QT_SYS_PATHS=ON -DBUILD_QT6=ON -DBUILD_QT5=OFF -DBUILD_TESTING=OFF \
 && cmake --build build --target breezedecoration \
 && mkdir /out && cp build/bin/org.kde.breeze.so /out/ && strip -g /out/org.kde.breeze.so

# ── the image ────────────────────────────────────────────────────────────────
FROM kinoite

LABEL org.opencontainers.image.title="Mauvely OS" \
      org.opencontainers.image.source="https://github.com/Mauvely/os-image" \
      org.opencontainers.image.licenses="GPL-3.0-or-later" \
      containers.bootc="1" \
      ostree.bootable="1"

# Browsers are Flatpaks the plane installs, so the admin controls them. Kinoite
# ships Firefox as an RPM, with its langpacks.
# Discover's rpm-ostree backend goes too: the agent stages the image, and a
# second updater would stage one behind it.
# No terminal (Timur, 2026-10-22): Konsole, its part (Dolphin's terminal) and
# DrKonqi, the crash reporter that needs Konsole. An admin assigns the Konsole
# Flatpak to the collections that need one.
# Inter and JetBrains Mono are the Mauvely look's interface and fixed-width fonts.
# dnf leaves a cache, a log, a /run directory and, after an install, per-repo
# state in /var/lib/dnf/repos, all of which `bootc container lint` flags.
RUN dnf -y remove firefox firefox-langpacks plasma-discover-rpm-ostree \
      konsole konsole-part plasma-drkonqi \
 && dnf -y install --setopt=install_weak_deps=False rsms-inter-fonts jetbrains-mono-fonts \
 && dnf clean all \
 && rm -rf /run/dnf /var/cache/libdnf5 /var/log/dnf5.log* /var/lib/dnf/repos

# The agent, and mauvely-session, which says in each person's session when a
# restart will finish an update. Both only start when /etc/mauvely/server
# exists, which the installer writes. mauvely-look runs mauvely-session once at
# each sign-in, before Plasma's shell: the collection's preset and a panel
# reset. The seal unit and its script come in with rootfs/.
COPY --from=agent-build /src/target/release/mauvelyd /usr/bin/mauvelyd
COPY --from=agent-build /src/target/release/mauvely-session /usr/bin/mauvely-session
COPY --from=agent dist/mauvelyd.service /usr/lib/systemd/system/mauvelyd.service
COPY --from=agent dist/mauvely-session.service /usr/lib/systemd/user/mauvely-session.service
COPY --from=agent dist/mauvely-look.service /usr/lib/systemd/user/mauvely-look.service
COPY rootfs/ /

# The sign-in window: /usr/bin/mauvely-signin, its desktop file (com.mauvely.signin,
# hidden from menus) and its icon. mauvely-session starts it with the code on its
# standard input, and falls back to kdialog without it. The base already has
# qt6-qtwebengine and qt6-qtsvg. A bad first line exits 2, which it only reaches
# once every library loaded: a Qt in the builder newer than the base's fails here.
# The icon cache is rebuilt because ostree sets every mtime to 1970, so a cache
# that does not list the new icon would never look stale.
COPY --from=signin-build /out/usr/ /usr/
RUN rpm -q qt6-qtwebengine qt6-qtsvg \
 && (printf '{}\n' | /usr/bin/mauvely-signin; test $? -eq 2) \
 && desktop-file-validate /usr/share/applications/com.mauvely.signin.desktop \
 && grep -qx 'NoDisplay=true' /usr/share/applications/com.mauvely.signin.desktop \
 && gtk-update-icon-cache -f /usr/share/icons/hicolor \
 && grep -q com.mauvely.signin /usr/share/icons/hicolor/icon-theme.cache

# The Mauvely look (brief 25), from rootfs/: the global themes Mauvely light and
# Mauvely dark, switched by time of day, and the Plasma preset (Breeze with the
# violet accent); their colour schemes, the "mauvely" Plasma style, the
# wallpaper, and the start glyph (in the icon cache rebuilt above). The image's
# KDE defaults are /usr/share/mauvely/xdg, which /etc/profile.d/mauvely-xdg.sh
# puts ahead of Fedora's profile in XDG_CONFIG_DIRS; HANDOFF.md has why there.
# - Breeze's decoration is replaced with the one built above. It must load with
#   every symbol resolved against the image's libraries.
# - The Plasma preset borrows Breeze's own splash and previews: a global
#   theme's splash setting only applies when the package has a splash.
# - Light and dark share their layout and splash, byte for byte.
# - The last four checks read the defaults the way a session does, from a
#   shell with no XDG_CONFIG_DIRS of its own: Mauvely's must win over Fedora's.
COPY --from=breeze-build /out/org.kde.breeze.so /usr/lib64/qt6/plugins/org.kde.kdecoration3/org.kde.breeze.so
RUN so=/usr/lib64/qt6/plugins/org.kde.kdecoration3/org.kde.breeze.so \
 && python3 -I -c 'import ctypes, os, sys; ctypes.CDLL(sys.argv[1], os.RTLD_NOW)' "$so" \
 && grep -qa CornerRadius "$so" \
 && lnf=/usr/share/plasma/look-and-feel \
 && cp -r "$lnf/org.kde.breeze.desktop/contents/splash" "$lnf/org.kde.breeze.desktop/contents/previews" \
      "$lnf/com.mauvely.plasma.desktop/contents/" \
 && for d in layoutdefaults layouts splash; do \
      diff -r "$lnf/com.mauvely.light.desktop/contents/$d" "$lnf/com.mauvely.dark.desktop/contents/$d"; \
    done \
 && for id in light dark plasma; do \
      kpackagetool6 -t Plasma/LookAndFeel -g -l | grep -qx "com.mauvely.$id.desktop"; \
    done \
 && for f in "$lnf"/com.mauvely.*/metadata.json /usr/share/plasma/desktoptheme/mauvely/metadata.json \
      /usr/share/wallpapers/Mauvely/metadata.json; do \
      python3 -I -c 'import json, sys; json.load(open(sys.argv[1]))' "$f"; \
    done \
 && fc-match -f '%{family}\n' 'Inter' | grep -q '^Inter' \
 && fc-match -f '%{family}\n' 'JetBrains Mono' | grep -q '^JetBrains Mono' \
 && grep -q com.mauvely.start /usr/share/icons/hicolor/icon-theme.cache \
 && read_default() { env -u XDG_CONFIG_DIRS sh -c '. /etc/profile.d/mauvely-xdg.sh && kreadconfig6 "$@"' sh "$@"; } \
 && test "$(read_default --file kdeglobals --group KDE --key LookAndFeelPackage)" = com.mauvely.light.desktop \
 && read_default --file kicker-extra-favoritesrc --group General --key Prepend | grep -q '^preferred://browser;org.kde.dolphin.desktop;' \
 && test "$(read_default --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key Image)" \
      = file:///usr/share/wallpapers/Mauvely/ \
 && test "$(read_default --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnRight)" = IAX

# Mauvely OS, and nothing more: the name, the About page and the logo. ID and
# VERSION_ID stay Fedora's, so dnf, flatpak and bootc are unaffected, and so do
# the OSTREE_VERSION, CPE_NAME and REDHAT_* lines. The URLs that pointed at
# Fedora Kinoite's support pages go.
RUN . /usr/lib/os-release \
 && sed -i -E \
      -e '/^(ANSI_COLOR|LOGO|HOME_URL|DOCUMENTATION_URL|SUPPORT_URL|BUG_REPORT_URL)=/d' \
      -e 's|^NAME=.*|NAME="Mauvely OS"|' \
      -e 's|^VERSION="([^ ]+) \(.*\)"|VERSION="\1 (Mauvely OS)"|' \
      -e "s|^PRETTY_NAME=.*|PRETTY_NAME=\"Mauvely OS (Fedora ${VERSION_ID} base)\"|" \
      -e 's|^VARIANT=.*|VARIANT="Mauvely OS"|' \
      -e 's|^VARIANT_ID=.*|VARIANT_ID=mauvely|' \
      /usr/lib/os-release \
 && printf '%s\n' 'ANSI_COLOR="0;38;2;150;138;224"' 'LOGO=mauvely-logo' 'HOME_URL="https://mauvely.com"' \
      >> /usr/lib/os-release \
 && grep -qx 'NAME="Mauvely OS"' /usr/lib/os-release \
 && grep -qx 'VARIANT_ID=mauvely' /usr/lib/os-release \
 && grep -q '^PRETTY_NAME="Mauvely OS ' /usr/lib/os-release \
 && grep -qx 'ID=fedora' /usr/lib/os-release

# Images from ghcr.io/mauvely/os must carry Mauvely's cosign signature
# (brief 19, T4). `bootc switch` and `bootc upgrade` pull through
# containers/image, which applies this policy, so an unsigned or foreign image
# under that name is refused before anything is staged. The rule is added to
# the base's own policy rather than replacing it; the base allows anything by
# default, and other registries keep that. registries.d/mauvely-os.yaml, in
# rootfs/, tells containers/image where the signatures are.
COPY keys/cosign.pub /etc/pki/containers/mauvely-os.pub
RUN python3 -c 'import json; p = "/etc/containers/policy.json"; d = json.load(open(p)); d.setdefault("transports", {}).setdefault("docker", {})["ghcr.io/mauvely/os"] = [{"type": "sigstoreSigned", "keyPath": "/etc/pki/containers/mauvely-os.pub", "signedIdentity": {"type": "matchRepository"}}]; json.dump(d, open(p, "w"), indent=4)' \
 && python3 -c 'import json; r = json.load(open("/etc/containers/policy.json"))["transports"]["docker"]["ghcr.io/mauvely/os"]; assert r[0]["type"] == "sigstoreSigned", r' \
 && grep -q 'BEGIN PUBLIC KEY' /etc/pki/containers/mauvely-os.pub

# Discover installs Flatpak updates unattended by default. The agent updates
# them (brief 22, U2).
RUN sed -i 's/^UseUnattendedUpdates=true$/UseUnattendedUpdates=false/' /etc/xdg/PlasmaDiscoverUpdates \
 && grep -qx 'UseUnattendedUpdates=false' /etc/xdg/PlasmaDiscoverUpdates

# Units.
# - enabled: the agent, and the seal that runs before it.
# - masked: everything in the base that applies an update and reboots, or that
#   would stage one behind the agent's back. The agent stages and never reboots.
# - masked: flatpak-add-fedora-repos, which adds the `fedora` OCI remotes on first
#   boot. Remotes come from the agent, out of the server's check-in answer.
# - masked: rpm-ostree-countme, which reports each machine to Fedora's mirrors.
# Plasma Setup stays enabled: in milestone 1 it makes the first local account.
RUN systemctl enable mauvelyd.service mauvely-seal.service \
 && systemctl --global enable mauvely-session.service mauvely-look.service \
 && systemctl mask \
      bootc-fetch-apply-updates.timer bootc-fetch-apply-updates.service \
      rpm-ostreed-automatic.timer rpm-ostreed-automatic.service \
      flatpak-add-fedora-repos.service \
      rpm-ostree-countme.timer rpm-ostree-countme.service

# The boot splash (brief 25): Plymouth's two-step plugin with the Mauvely mark
# where the splash screen puts it, on the same ground. The spinner, the disk
# unlock prompt's images and the rest are Fedora's spinner theme's; only the
# watermark is Mauvely's. `rhgb quiet` come from
# /usr/lib/bootc/kargs.d/10-mauvely-splash.toml, and the initramfs rebuilt
# below carries the theme.
RUN t=/usr/share/plymouth/themes/mauvely \
 && find /usr/share/plymouth/themes/spinner -maxdepth 1 -name '*.png' ! -name watermark.png -exec cp -t "$t" {} + \
 && test -f "$t/throbber-0001.png" && test -f "$t/lock.png" && test -f "$t/watermark.png" \
 && sed -i 's/^Theme=bgrt$/Theme=mauvely/' /usr/share/plymouth/plymouthd.defaults \
 && test "$(plymouth-set-default-theme)" = mauvely

# The initramfs, rebuilt with rootfs/usr/lib/dracut/dracut.conf.d/90-mauvely-
# initramfs.conf so that two kernels fit in /boot. Fails the build past 150 MB,
# which is about where an update stops fitting next to the booted kernel,
# without the ostree module, without which nothing boots, and without the
# Plymouth theme.
RUN kver="$(ls /usr/lib/modules)" \
 && dracut --force --no-hostonly --reproducible --kver "$kver" "/usr/lib/modules/$kver/initramfs.img" \
 && lsinitrd -m "/usr/lib/modules/$kver/initramfs.img" | grep -qx ostree \
 && lsinitrd "/usr/lib/modules/$kver/initramfs.img" | grep -q 'usr/share/plymouth/themes/mauvely/watermark.png' \
 && size="$(stat -c %s "/usr/lib/modules/$kver/initramfs.img")" \
 && echo "initramfs: $size bytes" \
 && [ "$size" -lt 157286400 ]

RUN bootc container lint
