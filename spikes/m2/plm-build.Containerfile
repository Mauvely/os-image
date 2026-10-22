# Brief 26 spike: Plasma Login Manager with plm-second-prompt.patch as Patch1003,
# from the signed Fedora source RPM, on the base os-image pins. The RPMs land in /out.
#   podman build -f spikes/m2/plm-build.Containerfile -t plm-build spikes/m2
# Move the FROM line with the Containerfile's base.
FROM quay.io/fedora-ostree-desktops/kinoite:44.20261019.0
COPY plm-second-prompt.patch /patch/
RUN vr="$(rpm -q --qf '%{VERSION}-%{RELEASE}' plasma-login-manager)" \
 && echo "building plasma-login-manager-$vr" \
 && dnf -q versionlock add $(rpm -qa --qf '%{NAME}\n' | sort -u) >/dev/null \
 && dnf -y install --setopt=install_weak_deps=False rpm-build ninja-build \
 && mkdir -p /src && cd /src \
 && dnf download --source --enablerepo=fedora-source --enablerepo=updates-source "plasma-login-manager-$vr" \
 && rpmkeys --dbpath /src/keys --import "/etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-$(rpm -E %fedora)-primary" \
 && rpmkeys --dbpath /src/keys --checksig "plasma-login-manager-$vr.src.rpm" | grep -q 'signatures OK' \
 && rpm -i --define '_topdir /src/rpmbuild' "plasma-login-manager-$vr.src.rpm" \
 && cp /patch/plm-second-prompt.patch /src/rpmbuild/SOURCES/ \
 && sed -i '/^Patch1002:/a Patch1003:      plm-second-prompt.patch' /src/rpmbuild/SPECS/plasma-login-manager.spec \
 && sed -i 's/^Release:\(\s*\)\([0-9]*\)/Release:\1\2.mauvely1/' /src/rpmbuild/SPECS/plasma-login-manager.spec \
 && grep -n '^Patch1003\|^Release' /src/rpmbuild/SPECS/plasma-login-manager.spec \
 && dnf -y builddep --setopt=install_weak_deps=False /src/rpmbuild/SPECS/plasma-login-manager.spec \
 && rpmbuild --define '_topdir /src/rpmbuild' --define '_smp_mflags -j8' --nocheck -bb /src/rpmbuild/SPECS/plasma-login-manager.spec \
 && mkdir /out && cp /src/rpmbuild/RPMS/*/*.rpm /out/ && ls -la /out
