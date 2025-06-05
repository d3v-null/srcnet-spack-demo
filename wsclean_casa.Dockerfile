# docker build . -f wsclean_casa.Dockerfile -t wsclean_casa && docker run -it wsclean_casa /bin/bash

# ---------------------------
# Builder Stage: Build environment, install dependencies, and generate Spack view
# ---------------------------
FROM spack/ubuntu-jammy:0.23.0 AS builder

# note to replicate some of these steps in your own container, you should first:
# . /opt/spack/share/spack/setup-env.sh

# some packages must be installed by apt in addition to spack.
# mount apt cache for faster builds.
# -> wget: casacore packagse misses this as a build dependency
#   ==> Installing casacore-3.6.1-4e6f2sbww43az7spzgi77inyyr4ewura [192/234]
#   sh: 1: wget: not found
# -> others ( autoconf, automake, cmake, libtool, m4, pkg-config ) are build-only deps.
#   discovered with spack external find
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt update && apt-get --no-install-recommends install -y \
    autoconf \
    automake \
    cmake \
    libtool \
    m4 \
    pkg-config \
    wget \
    zlib1g-dev \
    libbz2-dev \
    ;
# liblapack-dev \
# libopenmpi-dev \
# libhdf5-dev \

# Clone the custom Spack repository from GitLab
RUN git clone https://gitlab.com/ska-telescope/sdp/ska-sdp-spack.git /opt/ska-sdp-spack && \
    spack repo add /opt/ska-sdp-spack

# Create a new Spack environment which writes to /opt
# mount buildcache for faster builds.
RUN --mount=type=cache,target=/opt/buildcache \
    mkdir -p /opt/{software,spack_env,view} && \
    spack env create --dir /opt/spack_env && \
    spack env activate /opt/spack_env && \
    spack external find --all && \
    spack config remove packages:python && \
    spack mirror add --autopush --unsigned mycache file:///opt/buildcache && \
    spack config add "config:install_tree:root:/opt/software" && \
    spack config add "view:/opt/view" && \
    spack add \
        wsclean \
    && \
    spack concretize && \
    spack install --no-check-signature --fail-fast --no-checksum -j1

# && \
# spack gc -y

# Optionally, reduce the size by stripping binaries
# RUN find -L /opt/view/* -type f -exec strip -s {} \;

# ---------------------------
# Final Stage: Create a lean runtime image
# ---------------------------
# FROM images.canfar.net/skaha/base-notebook:latest AS runtime
FROM ubuntu:22.04 AS runtime

# Install minimal dependencies needed to bootstrap spack env
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get --no-install-recommends install -y \
    python3 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create symlinks for python and pip
RUN ln -sf /usr/bin/python3 /usr/bin/python

# Copy necessary files from builder
COPY --from=builder /opt/software /opt/software
COPY --from=builder /opt/view /opt/view
COPY --from=builder /opt/spack_env /opt/spack_env
COPY --from=builder /opt/spack /opt/spack
COPY --from=builder /opt/ska-sdp-spack /opt/ska-sdp-spack

# Setup Spack environment
ENV SPACK_ROOT=/opt/spack \
    PATH=/opt/view/bin:/opt/software/bin:/usr/local/bin:/usr/bin:/bin
RUN . /opt/spack/share/spack/setup-env.sh && \
    spack repo add /opt/ska-sdp-spack && \
    spack env activate /opt/spack_env && \
    echo ". /opt/spack/share/spack/setup-env.sh" >>/etc/profile.d/spack.sh && \
    echo "spack env activate /opt/spack_env" >>/etc/profile.d/spack.sh && \
    . /etc/profile.d/spack.sh

# Create a startup script that activates the environment
RUN echo '#!/bin/bash' >/usr/local/bin/entrypoint.sh && \
    echo 'source /opt/spack/share/spack/setup-env.sh' >>/usr/local/bin/entrypoint.sh && \
    echo 'spack env activate /opt/spack_env' >>/usr/local/bin/entrypoint.sh && \
    echo 'exec "$@"' >>/usr/local/bin/entrypoint.sh && \
    chmod +x /usr/local/bin/entrypoint.sh

# Set the entrypoint to our custom script
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash", "-l"]
