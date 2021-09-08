Tag: superfluous-file-pattern
Severity: warning
Check: debian/copyright/dep5
Rename-from:
 wildcard-matches-nothing-in-dep5-copyright
Explanation: The wildcard that was specified matches no file in the source tree.
 This either indicates that you should fix the wildcard so that it matches
 the intended file or that you can remove the wildcard. Notice that in
 contrast to shell globs, the "&ast;" (star or asterisk) matches slashes and
 leading dots.
See-Also:
 https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
