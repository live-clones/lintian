Tag: source-only-upload-to-non-free-without-autobuild
Severity: error
Check: archive/non-free/autobuild
Explanation: For licensing reasons, packages in the non-free section are by default
 not built automatically. This source-upload to non-free will never result in built
 packages appearing in the archive.
 .
 Please perform an upload that includes installable packages. After checking the
 license, you can alternatively add <code>XS-Autobuild: yes</code> to the source
 paragraph of <code>debian/control</code> and ask for the source to be added to the
 <code>autobuild</code> whitelist.
See-Also:
 devref 5.10.5
