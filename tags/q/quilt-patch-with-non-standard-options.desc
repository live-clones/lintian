Tag: quilt-patch-with-non-standard-options
Severity: warning
Check: debian/patches/quilt
Explanation: The quilt series file contains non-standard options to apply some of
 the listed patches. Quilt uses '-p1' by default if nothing is specified
 after the name of the patch and the current series file specify something
 else for some of the patches listed.
 .
 For compatibility with the source "3.0 (quilt)" source package format,
 you should avoid using any option at all and make sure that your patches
 apply with "-p1". This can be done by refreshing all patches like this:
 quilt pop -a; while quilt push; do quilt refresh -pab; done
