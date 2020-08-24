Tag: source-contains-prebuilt-flash-object
Severity: pedantic
Check: cruft
Explanation: The source tarball contains a prebuilt file in the Shockwave Flash (SWF)
 or Flash Video (FLV) format. These are often included by mistake when
 developers generate a tarball without cleaning the source directory
 first. An exception is simple video files, which are their own
 source.
 .
 If there is no sign this was intended, consider reporting it as an
 upstream bug.
 .
 If the Flash file is not meant to be modified directly, please make
 sure the package includes the source for the file and that the
 packaging rebuilds it.
