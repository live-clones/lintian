Tag: patch-file-present-but-not-mentioned-in-series
Severity: warning
Check: debian/patches/quilt
Explanation: The specified patch is present under the <code>debian/patches</code>
 directory but is not mentioned in any "series" or "00list" file.
 .
 This may mean that a patch was created with the intention of modifying
 the package but is not being applied.
 .
 Please either add the filename to the series file, or ensure it is
 commented-out in a form that Lintian can recognise, for example:
 .
   0001&lowbar;fix-foo.patch
   # 0002&lowbar;fix-bar.patch
