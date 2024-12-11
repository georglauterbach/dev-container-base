# We use Ubuntu as a base because it comes with
# frequent updates and a wide variety of packages.
ARG UBUNTU_VERSION=24.04
FROM docker.io/ubuntu:${UBUNTU_VERSION}

# We use bash and not sh.
SHELL [ "/bin/bash", "-o", "pipefail", "-eE", "-u", "-c" ]

# The user from the Ubuntu base image is `ubuntu`. We provide
# environment variables that we need later anyway right here.
ENV USER=ubuntu
ENV HOME="/home/${USER}"

# These environment variables are used by APT and dpkg. Their
# values make APT and dpkg behave as non-interactive.
ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN=true

# These variables are used to determine the version of Hermes
# this this image is base upon. To propagate the version, a
# more descriptive ENV variable is used too.
ARG HERMES_VERSION='v3.0.0-beta.5'
ENV DEV_CONTAINER_BASE_HERMES_VERSION=${HERMES_VERSION}

# Firstly, we make sure we have all base package that
# we need as well as all updates.
#
# hadolint ignore=DL3005,DL3008
RUN <<EOM
  # Make sure we use the most recent versions of packages
  # from the base image. Here, `dist-upgrade` is okay as well,
  # because we do not have prior commands installing software
  # that could potentially be damaged.
  apt-get --yes update
  apt-get --yes dist-upgrade
  apt-get --yes install --no-install-recommends \
    apt-utils ca-certificates curl dialog doas file locales

  # This URI is for convenience and keeps `curl` and the like short, correct and concise.
  readonly HERMES_BASE_URI='https://raw.githubusercontent.com/georglauterbach/hermes'

  # We run Hermes (https://github.com/georglauterbach/hermes) here
  # to easily set up default tools and configurations.
  curl --silent --show-error --fail --location --output /usr/local/bin/hermes \
    "https://github.com/georglauterbach/hermes/releases/download/${HERMES_VERSION}/hermes-${HERMES_VERSION}-$(uname -m)-unknown-linux-musl"
  chmod +x /usr/local/bin/hermes
  hermes --non-interactive

  # We update the locales next. We want en_US.UTF-8 to be the standard locale.
  curl -sSfL -o /usr/local/bin/update_locales.sh \
    "${HERMES_BASE_URI}/refs/tags/${HERMES_VERSION}/misc/setup_locales.sh"
  chmod +x /usr/local/bin/update_locales.sh
  update_locales.sh 'en_US.UTF-8'

  # Last but not least, we clean up superfluous cache files from APT.
  apt-get --yes autoremove
  apt-get --yes clean
  rm -rf /var/lib/apt/lists/* /tmp/*
EOM

# We installed Hermes (https://github.com/georglauterbach/hermes) in the RUN stage
# before, and we enable extra console configurations by setting these environment
# variables.
ENV HERMES_LOAD_EXTRA_PROGRAMS=true
ENV HERMES_LOAD_ALIASES=true

# We need to make sure that these directories have correct
# permissions, so that when mounting volumes to them, they
# can be used correctly.
RUN <<EOM
  # We create the `extensions/` directory, but we adjust permissions for the parent
  # directory - this is intended. Otherwise, the permissions, when one mounts a
  # volume to `extensions/`, will be wrong (the directory may belong to `root`
  # instead of `${USER}`).
  mkdir -p "${HOME}/.vscode-server/extensions"
  chown -R "${USER}:${USER}" "${HOME}/.vscode-server"

  mkdir -p "${HOME}/.cache"
  chown -R "${USER}:${USER}" "${HOME}/.cache"
EOM

# This stage set's up the previously installed package `doas`, a
# sudo replacement. We configure it so that the user `ubuntu` can
# password-less execute root commands by running `sudo ...`.
RUN <<EOM
  echo "permit nopass ${USER}" >/etc/doas.conf
  chown root:root /etc/doas.conf
  chmod 0400 /etc/doas.conf
  doas -C /etc/doas.conf
  ln -s "$(command -v doas)" /usr/local/bin/sudo
EOM

# Now, we switch to the user `${USER}` and set the home
# directory as the new current working directory.
USER "${USER}"
WORKDIR "${HOME}"

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
# (implicitly affects RUN). Thus, to maximize cache, keep
# these lines last:
ARG VCS_RELEASE=edge
ARG VCS_REVISION=unknown

# This variable can be used to determine whether you are
# inside a Development Container. If it set, you are inside
# a Development Container that uses this image as a base.
# It contains the version of this image and the version
# control system revision, separated by a dash.
ENV DEV_CONTAINER_BASE_VERSION=${VCS_RELEASE}#${VCS_REVISION}

# Last but not least, we provide the version information
# for this image.
LABEL org.opencontainers.image.version=${VCS_RELEASE}
LABEL org.opencontainers.image.revision=${VCS_REVISION}
