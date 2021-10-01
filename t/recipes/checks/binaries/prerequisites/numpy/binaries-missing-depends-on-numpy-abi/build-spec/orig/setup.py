import distutils.core

distutils.core.setup(
	ext_modules=[distutils.core.Extension('basic', ['basic.c'])]
)
