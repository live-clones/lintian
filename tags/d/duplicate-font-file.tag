Tag: duplicate-font-file
Severity: warning
Check: fonts
Explanation: This package appears to include a font file that is already provided
 by another package in Debian. Ideally it should instead depend on the
 relevant font package. If the application in this package loads the font
 file by name, you may need to include a symlink pointing to the file name
 of the font in its Debian package.
 .
 Sometimes the font package containing the font is huge and you only need
 one font. In that case, you have a few options: modify the package (in
 conjunction with upstream) to use libfontconfig to find the font that you
 prefer but fall back on whatever installed font is available, ask that
 the font package be split apart into packages of a more reasonable size,
 or add an override and be aware of the duplication when new versions of
 the font are released.
