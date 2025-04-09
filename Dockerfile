# We can use arbitrary base images, but we default to Ubuntu 24.04.
ARG BASE_IMAGE_REGISTRY=docker.io
ARG BASE_IMAGE_NAME=ubuntu
ARG BASE_IMAGE_TAG=24.04

FROM ${BASE_IMAGE_REGISTRY}/${BASE_IMAGE_NAME}:${BASE_IMAGE_TAG}

# The base image's user is required to make
# hermes run successfully later. The same goes
# for this user's home directory.
ARG BASE_IMAGE_USER=ubuntu
ARG BASE_IMAGE_HOME=/home/${BASE_IMAGE_USER}

# These variables are used to determine the version of Hermes this this image is base
# upon. To propagate the version, a more descriptive ENV variable is used too.
ARG HERMES_VERSION=v7.1.0
ENV DEV_CONTAINER_BASE_HERMES_VERSION=${HERMES_VERSION}

# This layer sets up core packages and acquires hermes.
# hadolint ignore=DL3005,DL3008
RUN <<EOM
#! /usr/bin/env -S bash -eE -u -o pipefail -O inherit_errexit

  source /etc/os-release
  case "${ID}" in
    ( 'debian' | 'ubuntu' )
      # These environment variables are used by APT and dpkg. Their # values make APT and
      # dpkg behave as non-interactive.
      export DEBIAN_FRONTEND=noninteractive
      export DEBCONF_NONINTERACTIVE_SEEN=true

      # We configure `tzdata` here so that we do not get prompted later when
      # installing packages (e.g. on an interactive shell).
      export TZ=Etc/UTC

      # We ensure we use the most recent versions of packages from the base image. Here,
      # `dist-upgrade` is okay as well, because we do not have prior commands installing
      # software that could potentially be damaged.
      apt-get --yes update
      apt-get --yes dist-upgrade
      apt-get --yes install --no-install-recommends \
        apt-utils ca-certificates curl dialog doas file locales tzdata

      # We also perform a proper cleanup
      apt-get --yes autoremove
      apt-get --yes clean
      rm -rf /var/lib/apt/lists/* /tmp/*

      # This stage sets up the previously installed package `doas`, a sudo replacement.
      # We configure it so that the user `ubuntu` can execute root commands password-less.
      echo "permit nopass ${BASE_IMAGE_USER}" >/etc/doas.conf
      chown root:root /etc/doas.conf
      chmod 0400 /etc/doas.conf
      doas -C /etc/doas.conf
      ln -s "$(command -v doas)" /usr/local/bin/sudo
      ;;

    ( * )
      echo "ERROR Currently, only Debian-like distributions are supported"
      exit 1
      ;;
  esac

  # We prepare hermes (https://github.com/georglauterbach/hermes) here to easily
  # set up default tools and configurations.
  curl --silent --show-error --fail --location --output /usr/local/bin/hermes \
    "https://github.com/georglauterbach/hermes/releases/download/${HERMES_VERSION}/hermes-${HERMES_VERSION}-$(uname -m)-unknown-linux-musl"
  chmod +x /usr/local/bin/hermes
EOM

# We switch to the user `${BASE_IMAGE_USER}` and set
# `${BASE_IMAGE_HOME}` as the new working directory.
USER ${BASE_IMAGE_USER}
WORKDIR ${BASE_IMAGE_HOME}

RUN <<EOM
#! /usr/bin/env -S bash -eE -u -o pipefail -O inherit_errexit

  hermes --verbose --non-interactive run --install-packages

  source /etc/os-release
  case "${ID}" in
    ( 'debian' | 'ubuntu' )
      doas apt-get --yes clean
      doas rm -rf /var/lib/apt/lists/* /tmp/*
      ;;

    ( * )
      echo "ERROR Currently, only Debian-like distributions are supported"
      exit 1
      ;;
  esac

  # The following directories are likely mount points, and need correct ownership.
  mkdir -p '.vscode-server/extensions' '.cache'
EOM

# Finally, we add metadata to the image.
LABEL org.opencontainers.image.title="Custom Development Container Base Image"
LABEL org.opencontainers.image.vendor="Georg Lauterbach (@georglauterbach) on GitHub"
LABEL org.opencontainers.image.authors="Georg Lauterbach (@georglauterbach)"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.description="A custom Development Container base image packed with as much as necessary and as few as possible configurations and applications to make development a breeze."
LABEL org.opencontainers.image.url="https://github.com/georglauterbach/dev-container-base"
LABEL org.opencontainers.image.documentation="https://github.com/georglauterbach/dev-container-base/blob/main/README.md"
LABEL org.opencontainers.image.source="https://github.com/georglauterbach/dev-container-base/blob/main/Dockerfile"

# ARG invalidates the build cache when it is used by a layer (implicitly affects RUN).
# Thus, to maximize cache, keep these lines last.
ARG VCS_RELEASE=edge
ARG VCS_REVISION=unknown

# This variable can be used to determine whether you are inside a Development
# Container. If it set, you are inside a Development Container that uses this
# image as a base. It contains the version of this image and the version
# control system revision, separated by a dash.
ENV DEV_CONTAINER_BASE_VERSION=${VCS_RELEASE}#${VCS_REVISION}

# Finally, we provide the version information for this image.
LABEL org.opencontainers.image.version=${VCS_RELEASE}
LABEL org.opencontainers.image.revision=${VCS_REVISION}
