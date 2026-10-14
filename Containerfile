# Mauvely OS: the image (brief 19, P5). The pinned Kinoite base, the device agent,
# one first-boot unit for the disk, and the removals that keep a machine's apps
# and updates in the management plane's hands.
#
# Build it with scripts/build.sh, which supplies the `agent` named context and
# warns when the agent checkout is not the commit pinned in agent.ref.

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

# ── the image ────────────────────────────────────────────────────────────────
# The tag is pinned to a dated build, never `latest` or a bare release number.
# Moving it is a deliberate commit. Fedora 44 is the newest stable release;
# 45 is still in Beta.
FROM quay.io/fedora-ostree-desktops/kinoite:44.20261013.0

LABEL org.opencontainers.image.title="Mauvely OS" \
      org.opencontainers.image.source="https://github.com/Mauvely/os-image" \
      org.opencontainers.image.licenses="GPL-3.0-or-later" \
      containers.bootc="1" \
      ostree.bootable="1"

# Browsers are Flatpaks the plane installs, so the admin controls them. Kinoite
# ships Firefox as an RPM, with its langpacks.
# dnf leaves a cache, a log and a /run directory that `bootc container lint` flags.
RUN dnf -y remove firefox firefox-langpacks \
 && dnf clean all \
 && rm -rf /run/dnf /var/cache/libdnf5 /var/log/dnf5.log*

# The agent. It only starts when /etc/mauvely/server exists, which the installer
# writes. The seal unit and its script come in with rootfs/.
COPY --from=agent-build /src/target/release/mauvelyd /usr/bin/mauvelyd
COPY --from=agent dist/mauvelyd.service /usr/lib/systemd/system/mauvelyd.service
COPY rootfs/ /

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

# Units.
# - enabled: the agent, and the seal that runs before it.
# - masked: everything in the base that applies an update and reboots, or that
#   would stage one behind the agent's back. The agent stages and never reboots.
# - masked: flatpak-add-fedora-repos, which adds the `fedora` OCI remotes on first
#   boot. Remotes come from the agent, out of the server's check-in answer.
# Plasma Setup stays enabled: in milestone 1 it makes the first local account.
RUN systemctl enable mauvelyd.service mauvely-seal.service \
 && systemctl mask \
      bootc-fetch-apply-updates.timer bootc-fetch-apply-updates.service \
      rpm-ostreed-automatic.timer rpm-ostreed-automatic.service \
      flatpak-add-fedora-repos.service

RUN bootc container lint
