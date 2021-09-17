Tag: source-contains-prebuilt-ms-help-file
Severity: error
Check: files/banned/compiled-help
Explanation: The source tarball contains a prebuilt Microsoft precompiled help
 file (CHM file). These are often included by mistake when developers generate
 a tarball without cleaning the source directory first.
 .
 CHM files are mainly produced by proprietary, Windows-specific software.
 They are also mainly consumed by the Microsoft HTML Help Workshop.
 .
 Whilst there is free software to read and write them, any
 examples existing in source packages are likely to be created
 by the proprietary Microsoft software and are probably missing
 the source HTML and associated files.
 .
 If there is no sign this was intended, consider reporting it as
 an upstream bug.
