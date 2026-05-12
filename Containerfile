ARG BASE_IMAGE=quay.io/hummingbird-community/bootc-os:latest
FROM ${BASE_IMAGE}

ARG ENABLE_FEDORA_RAWHIDE_REPO=0
ARG COPR_REPO=
ARG COPR_CHROOT=

RUN set -eux; \
    if [ "${ENABLE_FEDORA_RAWHIDE_REPO}" = "1" ]; then \
        printf '%s\n' \
            '[fedora-rawhide]' \
            'name=Fedora Rawhide - $basearch' \
            'metalink=https://mirrors.fedoraproject.org/metalink?repo=rawhide&arch=$basearch' \
            'enabled=1' \
            'gpgcheck=0' \
            > /etc/yum.repos.d/fedora-rawhide.repo; \
    fi

RUN set -eux; \
        if [ -n "${COPR_REPO}" ]; then \
            if ! dnf -y copr --help >/dev/null 2>&1; then \
                dnf -y install 'dnf5-command(copr)' \
                    || dnf -y install 'dnf-command(copr)' \
                    || dnf -y install dnf5-plugins \
                    || dnf -y install dnf-plugins-core; \
            fi; \
            if [ -n "${COPR_CHROOT}" ]; then \
                dnf -y copr enable "${COPR_REPO}" "${COPR_CHROOT}"; \
            else \
                dnf -y copr enable "${COPR_REPO}"; \
            fi; \
            dnf clean all; \
            rm -rf /var/cache/dnf; \
        fi

COPY packages/base-desktop.txt /tmp/packages.txt

RUN set -eux; \
    PKGS="$(grep -Ev '^\s*($|#)' /tmp/packages.txt | tr '\n' ' ')"; \
    if [ -n "${PKGS}" ]; then dnf -y --refresh --setopt=retries=20 --setopt=timeout=60 install ${PKGS}; fi; \
    dnf clean all; \
    rm -rf /var/cache/dnf /tmp/packages.txt

# Boot into a graphical session by default.
RUN ln -sf /usr/lib/systemd/system/graphical.target /etc/systemd/system/default.target

LABEL org.opencontainers.image.title="bootc-desktop"
LABEL org.opencontainers.image.description="Desktop-extended bootc image based on hummingbird-community/bootc-os"
LABEL org.opencontainers.image.source="local-workspace"
