# from https://gitlab.com/ska-telescope/sdp/ska-sdp-spack/-/blob/main/packages/py-ducc/package.py?ref_type=heads
import os

from spack.package import PythonPackage, depends_on, license, maintainers, version


class PyDucc(PythonPackage):
    """DEMO! Python bindings for Distinctly Useful Code Collection (DUCC)."""

    homepage = "https://gitlab.mpcdf.mpg.de/mtr/ducc"
    url = "https://gitlab.mpcdf.mpg.de/mtr/ducc.git"
    git = "https://gitlab.mpcdf.mpg.de/mtr/ducc.git"

    maintainers("saliei")

    license("Affero General Public License v1.0")

    version("0.36.0", tag="ducc0_0_36_0")
    version("0.35.0", tag="ducc0_0_35_0")
    version("0.34.0", tag="ducc0_0_34_0")

    depends_on("c", type="build")
    depends_on("cxx", type="build")
    depends_on("cmake", type="build")

    depends_on("python@3.8.0:", type="build")
    depends_on("py-setuptools@40.6.0:", type="build")
    depends_on("py-pybind11", type="build")
    depends_on("py-numpy@1.17.0:", type="build")

    depends_on("ducc", type=("build", "link"))

    def setup_build_environment(self, env):
        cmake_args = []
        cmake_args.append("-DDUCC_USE_THREADS=True")
        env.set("CMAKE_ARGS", " ".join(cmake_args))
        # a hack to overcome setuptools bug in not correctly
        # recognizing correct C++ Intel compiler.
        if "%oneapi" in self.spec:
            env.set("CC", os.environ.get("CXX"))
