# Mauvely OS: the image (brief 19, P5). The pinned Kinoite base, the device agent,
# the sign-in window, one first-boot unit for the disk, and the removals that
# keep a machine's apps and updates in the management plane's hands. Since
# brief 26, also signing in at the login screen with a Mauvely account.
#
# Build it with scripts/build.sh, which supplies the `agent` and `installer`
# named contexts and warns when either checkout is not the commit pinned in
# agent.ref or installer.ref. It also stages the `browser` context: the browser
# extension's packages and policies, which need keys (os-agent browser/package.py).

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
# pam-devel: pam_mauvely links against the system's libpam.
RUN dnf -y install --setopt=install_weak_deps=False cargo gcc pam-devel && dnf clean all
WORKDIR /src
# Named paths, not the whole context: a local checkout carries a target/ of
# several gigabytes.
COPY --from=agent Cargo.toml Cargo.lock ./
COPY --from=agent crates ./crates
COPY --from=agent tests ./tests
RUN cargo build --release --locked
# pam_mauvely (brief 26), when the agent at agent.ref builds it. The image
# below checks that it ships exactly when mauvelyd serves the login socket.
RUN mkdir -p /out/security \
 && if [ -e target/release/libpam_mauvely.so ]; then \
      cp target/release/libpam_mauvely.so /out/security/pam_mauvely.so; \
    fi

# ── mauvely-browser-host ─────────────────────────────────────────────────────
# The browser extension's native host (brief 22, S4; os-agent docs/browser.md).
# Firefox and Chromium run it inside their Flatpak sandboxes, from the person's
# ~/.var/app, where none of this image's libraries can be seen: so a static
# binary. Alpine's Rust targets musl and links statically by default; the check
# fails if that ever changes. The scratch stage then runs it with nothing else
# on the filesystem at all, which only a binary that needs nothing survives (no
# input is the end of input: it exits 0). The image copies it from there, so
# the check cannot be skipped.
FROM docker.io/library/rust:1.99.1-alpine3.24 AS host-build
ARG CARGO_BUILD_JOBS=8
WORKDIR /src
COPY --from=agent Cargo.toml Cargo.lock ./
COPY --from=agent crates ./crates
COPY --from=agent tests ./tests
RUN test "$(rustc -vV | sed -n 's/^host: //p')" = x86_64-unknown-linux-musl \
 && cargo build --release --locked -p mauvely-browser-host \
 && mkdir /out && cp target/release/mauvely-browser-host /out/

FROM scratch AS host-check
COPY --from=host-build /out/mauvely-browser-host /mauvely-browser-host
RUN ["/mauvely-browser-host"]

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

# ── Plasma Login Manager, with a second question and the device's people ─────
# Brief 26. patches/plasma-login-manager/: 0001 lets a PAM module ask something
# after the password (the code), 0002 makes the greeter follow
# /var/lib/mauvely-desktop/people.json. The same way as Breeze above: Fedora's
# signed source RPM of the base's exact plasma-login-manager, built against
# the base's version-locked libraries. Unlike Breeze, the whole package is
# built, since the daemon, the helper and the greeter all change: the patches
# go into the spec after Fedora's own, the Release gains ".mauvely1", and
# every RPM lands in /out. It first applies the patches to a prepared tree
# with --fuzz=0, so that one which no longer applies is named.
FROM kinoite AS plm-build
ARG CMAKE_BUILD_PARALLEL_LEVEL=8
COPY patches/plasma-login-manager/ /patches/
RUN vr="$(rpm -q --qf '%{VERSION}-%{RELEASE}' plasma-login-manager)" \
 && dnf -q versionlock add $(rpm -qa --qf '%{NAME}\n' | sort -u) >/dev/null \
 && dnf -y install --setopt=install_weak_deps=False rpm-build ninja-build \
 && mkdir -p /src && cd /src \
 && { dnf download --source --enablerepo=fedora-source --enablerepo=updates-source "plasma-login-manager-$vr" \
      || { echo "plm-build: Fedora no longer serves the source of plasma-login-manager-$vr; move the base (scripts/bump-base.sh)" >&2; exit 1; }; } \
 && rpmkeys --dbpath /src/keys --import "/etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-$(rpm -E %fedora)-primary" \
 && rpmkeys --dbpath /src/keys --checksig "plasma-login-manager-$vr.src.rpm" | grep -q 'signatures OK' \
 && rpm -i --define '_topdir /src/rpmbuild' "plasma-login-manager-$vr.src.rpm" \
 && spec=/src/rpmbuild/SPECS/plasma-login-manager.spec \
 && dnf -y builddep --setopt=install_weak_deps=False "$spec" \
 && rpmbuild --define '_topdir /src/rpmbuild' -bp "$spec" \
 && cd "$(find /src/rpmbuild/BUILD -maxdepth 2 -type d -name "plasma-login-manager-${vr%-*}")" \
 && for p in /patches/*.patch; do \
      patch -p1 --forward --batch --fuzz=0 < "$p" \
        || { echo "plm-build: $p no longer applies to plasma-login-manager-$vr; refresh it (HANDOFF.md)" >&2; exit 1; }; \
    done \
 && cd /src \
 && { grep -q '^%autosetup -p1' "$spec" \
      || { echo "plm-build: the spec no longer applies its patches with %autosetup -p1" >&2; exit 1; }; } \
 && cp /patches/*.patch /src/rpmbuild/SOURCES/ \
 && n=9000 && for p in /patches/*.patch; do \
      n=$((n + 1)) \
      && last="$(grep -n '^Patch[0-9]*:' "$spec" | tail -n 1 | cut -d: -f1)" \
      && sed -i "${last}a Patch$n: ${p##*/}" "$spec" || exit 1; \
    done \
 && sed -i -E 's/^(Release:[[:space:]]*)([0-9]+)/\1\2.mauvely1/' "$spec" \
 && grep -q '^Release:.*\.mauvely1' "$spec" \
 && test "$(grep -c '^Patch90[0-9][0-9]:' "$spec")" = "$(ls /patches/*.patch | wc -l)" \
 && rpmbuild --define '_topdir /src/rpmbuild' --define '_default_patch_fuzz 0' \
      --define "_smp_build_ncpus $CMAKE_BUILD_PARALLEL_LEVEL" --define 'debug_package %{nil}' -bb "$spec" \
 && mkdir /out && cp /src/rpmbuild/RPMS/*/*.rpm /out/

# ── the login socket's SELinux policy ────────────────────────────────────────
# selinux/: a type for /run/mauvely/auth.sock and connectto for the confined
# PAM callers (brief 26). Built against selinux-policy-devel at the base's own
# policy version.
FROM kinoite AS selinux-build
COPY selinux/ /src/
RUN dnf -q versionlock add $(rpm -qa --qf '%{NAME}\n' | sort -u) >/dev/null \
 && dnf -y install --setopt=install_weak_deps=False \
      "selinux-policy-devel-$(rpm -q --qf '%{VERSION}-%{RELEASE}' selinux-policy)" \
 && cd /src && make -f /usr/share/selinux/devel/Makefile mauvely.pp \
 && mkdir /out && cp mauvely.pp /out/

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
# Plasma Login Manager is replaced with plm-build's (brief 26), in this same
# step: each step that changes a package rewrites the whole RPM database
# (about 100 MB) into its layer. The rebuild's Release is the base's plus
# ".mauvely1", so `rpm -U` is a plain upgrade: it still checks dependencies
# and file conflicts, and nothing is forced. Every package the base has from
# that source RPM is upgraded, so the KCM stays at the daemon's exact version.
# The package brings /run/plasmalogin and /var/lib/plasmalogin back, which its
# tmpfiles.d makes at boot, so they go again, with the ldconfig cache rpm
# leaves.
# dnf leaves a cache, a log, a /run directory and, after an install, per-repo
# state in /var/lib/dnf/repos, all of which `bootc container lint` flags.
COPY --from=plm-build /out/ /tmp/plm/
RUN dnf -y remove firefox firefox-langpacks plasma-discover-rpm-ostree \
      konsole konsole-part plasma-drkonqi \
 && dnf -y install --setopt=install_weak_deps=False rsms-inter-fonts jetbrains-mono-fonts \
 && src="$(rpm -q --qf '%{SOURCERPM}' plasma-login-manager)" \
 && set -- \
 && for name in $(rpm -qa --qf '%{NAME} %{SOURCERPM}\n' | awk -v s="$src" '$2 == s { print $1 }'); do \
      rebuilt=; \
      for r in /tmp/plm/*.rpm; do [ "$(rpm -qp --qf '%{NAME}' "$r")" = "$name" ] && rebuilt="$r"; done; \
      [ -n "$rebuilt" ] || { echo "plm: the rebuild has no $name" >&2; exit 1; }; \
      set -- "$@" "$rebuilt"; \
    done \
 && rpm -Uvh "$@" \
 && dnf clean all \
 && rm -rf /run/dnf /var/cache/libdnf5 /var/log/dnf5.log* /var/lib/dnf/repos \
      /tmp/plm /run/plasmalogin /var/lib/plasmalogin /var/cache/ldconfig

# The agent, and mauvely-session, which says in each person's session when a
# restart will finish an update. Both only start when /etc/mauvely/server
# exists, which the installer writes. mauvely-look runs mauvely-session once at
# each sign-in, before Plasma's shell: the collection's preset and a panel
# reset. The seal unit and its script come in with rootfs/.
COPY --from=agent-build /src/target/release/mauvelyd /usr/bin/mauvelyd
COPY --from=agent-build /src/target/release/mauvely-session /usr/bin/mauvely-session
COPY --from=agent dist/mauvelyd.service /usr/lib/systemd/system/mauvelyd.service
COPY --from=agent dist/mauvely-login.service /usr/lib/systemd/system/mauvely-login.service
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

# Mauvely OS, and nothing more (Timur, 2026-10-22: the Fedora base belongs in the
# docs, not the name): the name, the About page and the logo. ID and
# VERSION_ID stay Fedora's, so dnf, flatpak and bootc are unaffected, and so do
# the OSTREE_VERSION, CPE_NAME and REDHAT_* lines. The URLs that pointed at
# Fedora Kinoite's support pages go.
RUN . /usr/lib/os-release \
 && sed -i -E \
      -e '/^(ANSI_COLOR|LOGO|HOME_URL|DOCUMENTATION_URL|SUPPORT_URL|BUG_REPORT_URL)=/d' \
      -e 's|^NAME=.*|NAME="Mauvely OS"|' \
      -e 's|^VERSION="([^ ]+) \(.*\)"|VERSION="\1 (Mauvely OS)"|' \
      -e 's|^PRETTY_NAME=.*|PRETTY_NAME="Mauvely OS"|' \
      -e 's|^VARIANT=.*|VARIANT="Mauvely OS"|' \
      -e 's|^VARIANT_ID=.*|VARIANT_ID=mauvely|' \
      /usr/lib/os-release \
 && printf '%s\n' 'ANSI_COLOR="0;38;2;150;138;224"' 'LOGO=mauvely-logo' 'HOME_URL="https://mauvely.com"' \
      >> /usr/lib/os-release \
 && grep -qx 'NAME="Mauvely OS"' /usr/lib/os-release \
 && grep -qx 'VARIANT_ID=mauvely' /usr/lib/os-release \
 && grep -qx 'PRETTY_NAME="Mauvely OS"' /usr/lib/os-release \
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

# The browser extension (brief 22, S4; os-agent docs/browser.md).
# - The native host, which mauvely-session copies into each browser's own
#   ~/.var/app directory with its manifest, at login.
# - The `browser` context, which scripts/build.sh stages with os-agent's
#   browser/package.py: Chromium's policy, CRX and update manifest, and
#   Firefox's policies.json and AMO-signed XPI. Each needs its key; without it
#   that tree is missing, and the image is otherwise the same.
# - rootfs/ has a mount unit per tree, enabled below, binding it at
#   /var/lib/flatpak/extension/<name>/x86_64/<branch>, where Flatpak mounts it
#   into that browser as an unmanaged extension. A unit whose tree is missing
#   mounts nothing.
# The checks: each tree is whole and agrees with itself, and the units' names
# are their mount points'.
COPY --from=host-check /mauvely-browser-host /usr/libexec/mauvely/mauvely-browser-host
COPY --from=browser . /usr/share/mauvely/browser/
RUN /usr/libexec/mauvely/mauvely-browser-host < /dev/null \
 && b=/usr/share/mauvely/browser \
 && for f in $(find "$b" -name '*.json'); do python3 -I -c 'import json, sys; json.load(open(sys.argv[1]))' "$f"; done \
 && c="$b/org.chromium.Chromium.Extension.mauvely" \
 && if [ -d "$c" ]; then \
      id="$(sed -n "s/.*appid='\([a-p]\{32\}\)'.*/\1/p" "$c/update.xml")" \
      && grep -q "\"$id;file:///app/chromium/extensions/mauvely/update.xml\"" "$c/policies/managed/com.mauvely.signin.json" \
      && test "$(head -c 4 "$c/mauvely-signin.crx")" = Cr24 \
      && echo "browser: Chromium extension $id"; \
    else echo "browser: no Chromium extension in this image"; fi \
 && f="$b/org.mozilla.firefox.systemconfig" \
 && if [ -d "$f" ]; then \
      grep -q 'file:///app/etc/firefox/mauvely/mauvely-signin.xpi' "$f/policies/policies.json" \
      && python3 -I -c 'import sys, zipfile; z = zipfile.ZipFile(sys.argv[1]); assert any(n.startswith("META-INF/") for n in z.namelist())' "$f/mauvely/mauvely-signin.xpi" \
      && echo "browser: Firefox extension, signed"; \
    else echo "browser: no Firefox extension in this image"; fi \
 && for m in org.chromium.Chromium.Extension.mauvely/x86_64/1 org.mozilla.firefox.systemconfig/x86_64/stable; do \
      test -f "/usr/lib/systemd/system/$(systemd-escape -p --suffix=mount "/var/lib/flatpak/extension/$m")"; \
    done

# Units.
# - enabled: the agent, the seal that runs before it, and the browser
#   extension's two mount units (above).
# - masked: everything in the base that applies an update and reboots, or that
#   would stage one behind the agent's back. The agent stages and never reboots.
# - masked: flatpak-add-fedora-repos, which adds the `fedora` OCI remotes on first
#   boot. Remotes come from the agent, out of the server's check-in answer.
# - masked: rpm-ostree-countme, which reports each machine to Fedora's mirrors.
# Plasma Setup stays enabled: in milestone 1 it makes the first local account.
RUN systemctl enable mauvelyd.service mauvely-login.service mauvely-seal.service \
 && systemctl enable var-lib-flatpak-extension-org.chromium.Chromium.Extension.mauvely-x86_64-1.mount \
      var-lib-flatpak-extension-org.mozilla.firefox.systemconfig-x86_64-stable.mount \
 && systemctl --global enable mauvely-session.service mauvely-look.service \
 && systemctl mask \
      bootc-fetch-apply-updates.timer bootc-fetch-apply-updates.service \
      rpm-ostreed-automatic.timer rpm-ostreed-automatic.service \
      flatpak-add-fedora-repos.service \
      rpm-ostree-countme.timer rpm-ostree-countme.service

# ── Signing in with a Mauvely account (brief 26) ─────────────────────────────
# Plasma Login Manager, installed from plm-build at the top. The checks: the
# daemon, the helper and the greeter are the rebuilt package's own files,
# resolve every library, and carry each patch.
RUN for f in /usr/bin/plasmalogin /usr/libexec/plasmalogin-helper /usr/libexec/plasma-login-greeter; do \
      { rpm -qf "$f" | grep -q '\.mauvely1\.' && ! ldd "$f" | grep -q 'not found'; } \
        || { echo "plm: $f is not the rebuilt one" >&2; exit 1; }; \
    done \
 && ! rpm -V --nomtime plasma-login-manager | grep -E ' /usr/(bin/plasmalogin|libexec/plasmalogin-helper|libexec/plasma-login-greeter)$' \
 && grep -qa 'Message received from greeter: Respond' /usr/bin/plasmalogin \
 && python3 -I -c 'import sys; sys.exit("/var/lib/mauvely-desktop/people.json".encode("utf-16-le") not in open(sys.argv[1], "rb").read())' \
      /usr/libexec/plasma-login-greeter \
 && ! find /etc /usr \( -name '*.rpmnew' -o -name '*.rpmsave' \) -print | grep .

# pam_mauvely and the PAM wiring. authselect's vendor profile "mauvely" is made
# from "local" here, not kept as a copy, so Fedora's next change to "local"
# reaches it. system-auth and password-auth gain three lines before pam_unix,
# in both auth and account:
#   [success=2 default=ignore]               pam_localuser.so
#   [success=1 default=ignore]               pam_localuser.so file=/usr/lib/passwd
#   [success=done ignore=ignore default=die] pam_mauvely.so
# - Anyone in /etc/passwd (root, the local accounts, break-glass) or in
#   /usr/lib/passwd (the system accounts, the login screen's own among them)
#   skips pam_mauvely, so a missing module or a dead daemon locks none of them
#   out.
# - For everyone else pam_mauvely decides: success ends the stack, PAM_IGNORE
#   falls through to pam_unix, anything else fails it.
# The image selects the profile with the base's own features. The checks:
# authselect's own; the profile differs from "local" by those six lines and
# nothing else; and they sit, in order, right before pam_unix. authselect's
# checksum in /var goes, as the base has none: /var is never updated from an
# image, and `authselect check` passes without it.
# pam_mauvely ships exactly when mauvelyd serves /run/mauvely/auth.sock. An
# agent.ref from before the socket builds no module; the lines then refuse
# nobody who could sign in before.
COPY --from=agent-build /out/security/ /usr/lib64/security/
RUN m=/usr/lib64/security/pam_mauvely.so \
 && if grep -qa 'auth\.sock' /usr/bin/mauvelyd; then \
      test -f "$m" || { echo "pam: mauvelyd serves the login socket, but agent.ref builds no pam_mauvely" >&2; exit 1; }; \
      python3 -I -c 'import ctypes, os, sys; ctypes.CDLL("libpam.so.0", os.RTLD_NOW | os.RTLD_GLOBAL); m = ctypes.CDLL(sys.argv[1], os.RTLD_NOW); m.pam_sm_authenticate; m.pam_sm_acct_mgmt' "$m"; \
    else \
      test ! -e "$m" || { echo "pam: pam_mauvely without the socket in mauvelyd" >&2; exit 1; }; \
    fi \
 && test "$(head -n 1 /etc/authselect/authselect.conf)" = local \
 && features="$(tail -n +2 /etc/authselect/authselect.conf | tr '\n' ' ')" \
 && authselect create-profile mauvely --vendor --base-on local --symlink-nsswitch --symlink-dconf \
      -s postlogin -s fingerprint-auth -s smartcard-auth -s switchable-auth -s REQUIREMENTS \
 && p=/usr/share/authselect/vendor/mauvely \
 && printf '%s\n' 'Mauvely OS' '==========' '' \
      'Local users, and people who sign in with their Mauvely account through pam_mauvely.' \
      'Made from "local" when the image is built (os-image, Containerfile).' > "$p/README" \
 && for f in system-auth password-auth; do \
      awk 'function ours(t) { \
             printf "%-12s%-45s%s\n", t, "[success=2 default=ignore]", "pam_localuser.so"; \
             printf "%-12s%-45s%s\n", t, "[success=1 default=ignore]", "pam_localuser.so file=/usr/lib/passwd"; \
             printf "%-12s%-45s%s\n", t, "[success=done ignore=ignore default=die]", "pam_mauvely.so" } \
           /^auth[ \t]+sufficient[ \t]+pam_unix\.so/ { ours("auth"); a++ } \
           /^account[ \t]+required[ \t]+pam_unix\.so/ { ours("account"); c++ } \
           { print } \
           END { exit !(a == 1 && c == 1) }' "$p/$f" > "$p/$f.new" \
        || { echo "authselect: $f: no single pam_unix line to put pam_mauvely before; read Fedora's local profile" >&2; exit 1; }; \
      mv "$p/$f.new" "$p/$f"; \
    done \
 && authselect select mauvely $features --force --nobackup \
 && authselect check \
 && test "$(head -n 1 /etc/authselect/authselect.conf)" = mauvely \
 && for f in system-auth password-auth; do \
      authselect test local $features --$f > /tmp/local \
      && authselect test mauvely $features --$f > /tmp/mauvely \
      && test -z "$(diff /tmp/local /tmp/mauvely | grep '^<')" \
      && test "$(diff /tmp/local /tmp/mauvely | grep -c '^>')" = 6 \
      && test "$(diff /tmp/local /tmp/mauvely | grep '^>' | grep -c 'pam_localuser\.so\|pam_mauvely\.so')" = 6 \
      && for t in auth account; do \
           awk -v t="$t" '$1 == t { for (i = 2; i <= NF; i++) if ($i ~ /^pam_[a-z0-9_]+\.so$/) { printf "%s ", $i; break } }' \
             "/etc/authselect/$f" | grep -q 'pam_localuser\.so pam_localuser\.so pam_mauvely\.so pam_unix\.so ' || exit 1; \
         done \
      && test "$(readlink "/etc/pam.d/$f")" = "/etc/authselect/$f" || { echo "authselect: $f is not as built" >&2; exit 1; }; \
    done \
 && rm -rf /tmp/local /tmp/mauvely /var/lib/authselect

# The login socket's SELinux policy, from selinux-build: /run/mauvely/auth.sock
# gets its own type, and only the confined PAM callers may connect (selinux/
# says which, and why those). The package stays in /usr/share/selinux/packages
# as well, the way Fedora's policy packages keep theirs.
COPY --from=selinux-build /out/mauvely.pp /usr/share/selinux/packages/mauvely.pp
RUN semodule -n -i /usr/share/selinux/packages/mauvely.pp \
 && semodule -l | grep -qx mauvely \
 && grep -q '^/run/mauvely/auth\\\.sock[[:space:]].*mauvely_auth_sock_t' /etc/selinux/targeted/contexts/files/file_contexts \
 && rm -rf /etc/selinux/targeted/previous

# Home folders for people, made by mauvely-home@<username>.service, which
# mauvelyd starts after a first sign-in (in rootfs/, with its guard).
RUN test -x /usr/libexec/mauvely/home-check \
 && systemd-analyze verify --man=no mauvely-home@check.service \
 && rm -f /run/systemd/systemd-units-load

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
