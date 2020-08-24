Tag: source-contains-prebuilt-pandoc-documentation
Severity: pedantic
Check: cruft
Explanation: The source tarball contains prebuilt pandoc documentation.
 This is usually left by mistake when generating the tarball without
 first cleaning the source directory. You may want to report this as
 an upstream bug if there is no sign that this was intended.
 .
 It is preferable to rebuild documentation directly from source.
