#!/usr/bin/python3

import distutils
import foo, bar, distutils.core
import foo, distutils.core, bara

# This should not match the uses-deprecated-python-stdlib tag
import distutils2
import notdistutils
