Tag: dependency-on-python-version-marked-for-end-of-life
Severity: pedantic
Check: languages/python
Experimental: yes
See-Also: https://wiki.debian.org/Python/Python3Port,
https://www.python.org/dev/peps/pep-0373/, Bug#897213
Explanation: The package specifies a dependency on Python 2.x which is due for
 deprecation and will not be maintained upstream past 2020 and will
 likely be dropped after the release of Debian "buster".
 .
 You should not make any changes to your package based on this presence
 of this tag.
 .
 However, please override this tag with a suitably-commented override if
 it is known that this package will not be migrated to Python 3.x for one
 reason or another. This is so that developers may ignore the package
 when looking for software that needs to be ported.
