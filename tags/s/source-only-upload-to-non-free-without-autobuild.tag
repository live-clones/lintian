Tag: source-only-upload-to-non-free-without-autobuild
Severity: error
Check: debian/control
Explanation: For licensing reasons packages from the non-free section are not
 built by the autobuilders by default, so this source-upload to
 "non-free" will result in the package never appearing in the archive.
 .
 Please either perform a regular binary upload or (after checking the
 license) add <tt>XS-Autobuild: yes</tt> into the header part of
 debian/control and get the package added to the "autobuild" whitelist.
See-Also: devref 5.10.5
