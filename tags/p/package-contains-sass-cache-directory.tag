Tag: package-contains-sass-cache-directory
Severity: warning
Check: files/names
Explanation: This package appears to ship a <tt>.sass-cache/</tt> directory,
 the result of running a the "Sass" utility that compiles CSS from SASS
 or SCSS files.
 .
 These are not useful in the binary package or to end-users. In
 addition, as they contain random/non-determinstic contents or
 filenames they can affect the reproducibility of the package.
 .
 Please ensure they are removed prior to final package build. For
 example, with:
 .
   override_dh_install:
           dh_install -X.sass-cache
See-Also: https://reproducible-builds.org/, #920595
