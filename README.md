# srcnet-spack-demo

there are two ways to install spack for this tutorial:

- install spack on your local machine
- run the tutorial in a container

## Setup: local installation

install spack on your local machine:

```bash
# install the spack command line tool
git clone https://github.com/spack/spack.git
. spack/share/spack/setup-env.sh
# add the ska-sdp-spack repository
git clone https://gitlab.com/ska-telescope/sdp/ska-sdp-spack.git
spack repo add ska-sdp-spack
```

### A note about editors

You will get a bunch of linter warnings in your package.py files unless you
ensure your editor has access to the spack python module installed above with

```bash
. ~/Code/spack/share/spack/setup-env.sh
export PYTHONPATH="${SPACK_ROOT}/lib/spack:${PYTHONPATH}"
open -a Cursor # or your editor of choice
```

### linux

Most linuxes should just work with

```bash
spack install wsclean
```

### macOS

if we just try installing wsclean like this, it won't work because nothing works with clang.

so we gotta get a bit more creative, and install some dependencies with brew.

```bash
brew install gcc make openblas boost wcslib mwatelescope/tap/cfitsio_reentrant
```

however this fails because apple clang cannot find fortran for openblas.

so we need to install the fortran compiler:

```bash
brew install gcc
```

and ensure spack can find it:

```bash
spack compiler find
```

and then install the wsclean package again with gcc

```bash
spack uninstall --all
spack install 'wsclean %gcc'
```

some issue with gmake, so we can use the brew installed version as an external.

edit `~/.spack/packages.yaml` with the installed version of gmake from

```bash
brew info make
```

and add the following to the file:

```yaml
packages:
  gmake:
    externals:
      - spec: gmake@4.4.1
        prefix: /opt/homebrew/opt/make
    buildable: False
```

```bash
spack clean -m
spack external find
```

and then install the wsclean package again:

```bash
spack install 'wsclean %gcc'
```
