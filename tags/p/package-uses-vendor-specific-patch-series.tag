Tag: package-uses-vendor-specific-patch-series
Severity: error
Check: debian/patches/quilt
Explanation: The specified series file for patches is vendor-specific.
 .
 Source packages may contain vendor (i.e. distribution) specific patches,
 but such packages must not be uploaded to the Debian archive if they
 are used in conjunction with vendor-specific series files.
 .
 Vendor specific series files were carefully implemented as a <code>dpkg</code>
 feature. Unfortunately, they currently conflict with some workflow goals
 in Debian. They are presently disallowed in Debian.
 .
 The preferred approach for distributions other than Debian is now to
 apply such patches programmatically via <code>debian/rules</code>. You can
 also create multiple, vendor-specific sources and upload them separately
 for each distribution.
 .
 The decision to prohibit the use of that particular <code>dpkg</code> feature
 in Debian was made by the project's technical committee in consideration of
 other planned workflow modifications, and may be revisited.
 .
 You should only see this tag in Debian or other distributions when 
 targeting an upload for Debian.
See-Also: Bug#904302, Bug#922531, https://lists.debian.org/debian-devel-announce/2018/11/msg00004.html
