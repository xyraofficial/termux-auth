from setuptools import setup
from Cython.Build import cythonize
from setuptools.extension import Extension
import sys

extensions = [
    Extension(
        "termux_auth_lib",
        ["termux_auth_core.pyx"],
        extra_compile_args=["-O3", "-fPIC"],
    )
]

setup(
    name="termux_auth_lib",
    ext_modules=cythonize(
        extensions,
        compiler_directives={
            'language_level': "3",
            'boundscheck': False,
            'wraparound': False,
        }
    ),
    zip_safe=False,
)
