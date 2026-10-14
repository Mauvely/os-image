# Mauvely OS: the image. Spike-grade for now (brief 19, P1): the pinned Kinoite
# base plus a marker. The real contents arrive in P5.
#
# The tag is pinned to a dated build, never `latest` or a bare release number.
# Moving it is a deliberate commit. Fedora 44 is the newest stable release;
# 45 is still in Beta.
FROM quay.io/fedora-ostree-desktops/kinoite:44.20261013.0

LABEL org.opencontainers.image.title="Mauvely OS" \
      org.opencontainers.image.source="https://github.com/Mauvely/os-image" \
      org.opencontainers.image.licenses="GPL-3.0-or-later" \
      containers.bootc="1" \
      ostree.bootable="1"

RUN printf 'NAME="Mauvely OS"\nSPIKE=P1\n' > /usr/lib/mauvely-release

RUN bootc container lint
