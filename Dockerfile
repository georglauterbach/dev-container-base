# We use Ubuntu as a base because it comes with
# frequent updates and a wide variety of packages.
ARG UBUNTU_VERSION=24.04
FROM docker.io/ubuntu:${UBUNTU_VERSION}

SHELL [ "/bin/bash", "-o", "pipefail", "-eE", "-u", "-c" ]

ENV USER=ubuntu

# Firstly, we make sure we have all base package that
# we need as well as all updates.
RUN <<EOM
  export DEBIAN_FRONTEND=noninteractive
  export DEBCONF_NONINTERACTIVE_SEEN=true

  apt-get --yes update
  apt-get --yes upgrade
  apt-get --yes install --no-install-recommends apt-utils ca-certificates curl doas

  # We run Hermes (https://github.com/georglauterbach/hermes) here to easily
  # set up default tools and configurations.
  export USER="${USER}"
  export HOME="/home/${USER}"
  export LOG_LEVEL='trace'
  curl --silent --show-error --fail --location --output '/tmp/setup.sh' \
    'https://raw.githubusercontent.com/georglauterbach/hermes/main/setup.sh'
  bash /tmp/setup.sh --assume-correct-incovation --assume-data-is-correct

  # Last but not least, we clean up superflous cache files from APT.
  apt-get --yes autoremove
  apt-get --yes clean
  rm -rf /var/lib/apt/lists/* /tmp/*
EOM

# This stage set's up the previously installed package `doas`, a
# sudo replacement. We configure it so that the user `ubuntu` can
# passwordless execute root commands by running `sudo ...`.
RUN <<EOM
  echo "permit nopass ${USER}" >/etc/doas.conf
  chown root:root /etc/doas.conf
  chmod 0400 /etc/doas.conf
  doas -C /etc/doas.conf
  ln -s "$(command -v doas)" /usr/local/bin/sudo
EOM

USER ${USER}
WORKDIR /home/${USER}

# Finally, we add metadata to the image.
LABEL org.opencontainers.image.title="Custom Development Container Base Image"
LABEL org.opencontainers.image.vendor="Georg Lauterbach (@georglauterbach) on GitHub"
LABEL org.opencontainers.image.authors="Georg Lauterbach (@georglauterbach)"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.description="A custom Development Container base image packed with as much as necessary and as few as possible configurations and applications to make development a breeze."
LABEL org.opencontainers.image.url="https://github.com/georglauterbach/dev-container-base"
LABEL org.opencontainers.image.documentation="https://github.com/georglauterbach/dev-container-base/blob/main/Dockerfile"
LABEL org.opencontainers.image.source="https://github.com/georglauterbach/dev-container-base/blob/main/README.md"

# ARG invalidates the build cache when it is used by a layer
# (implicitly affects RUN). Thus, to maximize cache, keep these lines last:
ARG VCS_RELEASE=edge
ARG VCS_REVISION=unknown

LABEL org.opencontainers.image.version=${VCS_RELEASE}
LABEL org.opencontainers.image.revision=${VCS_REVISION}
ENV VCS_RELEASE=${VCS_RELEASE}
