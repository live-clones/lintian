Tag: font-in-non-font-package
Severity: info
Check: fonts
Explanation: This package contains a &ast;.ttf, &ast;.otf, or &ast;.pfb file, file
 extensions used by TrueType, OpenType, or Type 1 fonts, but the package
 does not appear to be a dedicated font package. Dedicated font package
 names should begin with <code>fonts-</code>. (Type 1 fonts are also allowed
 in packages starting with <code>xfonts-</code>.) If the font is already
 packaged, you should depend on that package instead. Otherwise, normally
 the font should be packaged separately, since fonts are usually useful
 outside of the package that embeds them.
