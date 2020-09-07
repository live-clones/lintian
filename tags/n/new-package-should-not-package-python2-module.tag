Tag: new-package-should-not-package-python2-module
Severity: warning
Check: languages/python
Explanation: This package appears to be the initial packaging of a new upstream
 software package (ie. it contains a single changelog entry). However, it
 ships the specified module for Python 2.
 .
 Python 2.x modules should not be packaged unless strictly necessary (such
 as being explicitly requested by an end-user or required as part of a
 dependency chain) as the 2.x series of Python is due for deprecation and
 will not be maintained by upstream past 2020 and will likely be dropped
 after the release of Debian "buster".
 .
 If upstream have not moved or have no intention to move to Python 3,
 please be certain that Debian would benefit from the inclusion, continued
 maintenance burden and (eventual) removal of this package before you
 upload.
 .
 This warning can be ignored if the package is not intended for Debian or
 if it is a split of an existing Debian package. This warning can also be
 ignored if viewed on https://lintian.debian.org/.
 .
 Please do not override this warning; rather, add a justification to your
 changelog entry; Lintian looks in this version's changelog entry for the
 specified package name or the phrase "Python 2 version" or similar.
 This will ensure that any rationale is preserved for posterity.
