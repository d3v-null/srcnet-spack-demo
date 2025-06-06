# docker build . -f wsclean_casa.Dockerfile -t wsclean_casa --progress=plain && \
# docker run --rm -it --entrypoint=/bin/bash wsclean_casa -l

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
# create and activate a spack env
# find external deps installed in previous step, except python
# setup buildcache
# specify view location
# add packages to the env
# concretize the env
# install env
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

# create and add a demo spack repo
# spack add install additional in the previous env
RUN mkdir -p /opt/demo-spack
COPY repo.yaml /opt/demo-spack/repo.yaml
COPY packages /opt/demo-spack/packages
RUN --mount=type=cache,target=/opt/buildcache \
    spack env activate /opt/spack_env && \
    spack repo add /opt/demo-spack && \
    spack add py-ducc && \
    spack concretize --force && \
    spack install --no-check-signature --fail-fast --no-checksum -j1

# make it so that spack is available in the container (with bash -l)
RUN echo ". /opt/spack/share/spack/setup-env.sh" >> /etc/profile.d/spack.sh && \
    echo "spack env activate /opt/spack_env" >> /etc/profile.d/spack.sh && \
    . /etc/profile.d/spack.sh