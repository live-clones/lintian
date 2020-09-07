Tag: duplicate-files
Severity: pedantic
Check: files/duplicates
Experimental: yes
See-Also: jdupes(1)
Explanation: The package ships the two (or more) files with the exact same
 contents.
 .
 Duplicates can often be replaced with symlinks by running:
 .
    jdupes -rl debian/${binary}/usr
 .
 ... after they are installed, eg. in <code>override&lowbar;dh&lowbar;link</code>. In
 addition, please consider reporting this upstream.
 .
 Note: empty files are exempt from this check.
