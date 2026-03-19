Tag: quilt-patch-uses-dpatch-extension
Severity: info
Check: debian/patches/quilt
Explanation: quilt patch file uses <code>.dpatch</code> which points
 to the kind of patch files dpatch will consume which is long removed.
 Use <code>.diff</code> or <code>.patch</code> for quilt patch files.
