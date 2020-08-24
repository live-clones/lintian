Tag: shared-library-lacks-version
Severity: warning
Check: shared-libs
Renamed-From: shlib-without-versioned-soname
See-Also: policy 10.2, policy 8.6
Explanation: The listed shared library in a public library directory has an
 SONAME that does not contain any versioning information, either after the
 <tt>.so</tt> or before it and set off by a hyphen. It cannot therefore
 be represented in the shlibs system, and if linked by binaries its
 interface cannot safely change. There is no backward-compatible way to
 migrate programs linked against it to a new ABI.
 .
 Normally, this means the shared library is a private library for a
 particular application and is not meant for general use. Policy
 recommends that such libraries be installed in a subdirectory of
 <tt>/usr/lib</tt> rather than in a public shared library directory.
 .
 To view the SONAME of a shared library, run <tt>readelf -d</tt> on the
 shared library and look for the tag of type SONAME.
 .
 There are some special stub libraries or special-purpose shared objects
 for which an ABI version is not meaningful. If this is one of those
 cases, please add an override.
