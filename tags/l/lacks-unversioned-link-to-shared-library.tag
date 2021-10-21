Tag: lacks-unversioned-link-to-shared-library
Severity: warning
Check: libraries/shared/links
Renamed-From:
 dev-pkg-without-shlib-symlink
Explanation: A "-dev" package is supposed to install a "libsomething.so" symbolic
 link referencing the corresponding shared library. Notice how the link name
 doesn't include the version number -- this is because such a link is used
 by the linker when other programs are built against this shared library.
 .
 The symlink is generally expected in the same directory as the library
 itself. The major exception to this rule is if the library is installed
 in (or beneath) <code>/lib</code>, where the symlink must be installed in the
 same dir beneath <code>/usr</code>.
 .
 Example: If the library is installed in <code>/lib/i386-linux-gnu/libXYZ.so.V</code>,
 the symlink is expected at <code>/usr/lib/i386-linux-gnu/libXYZ.so</code>.
 .
 Implementation detail: This tag is emitted for the library package and not
 the "-dev" package.
See-Also:
 policy 8.4
