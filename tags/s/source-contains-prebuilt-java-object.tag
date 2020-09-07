Tag: source-contains-prebuilt-java-object
Severity: pedantic
Check: languages/java
Explanation: The source tarball contains a prebuilt Java class file. These are often
 included by mistake when developers generate a tarball without cleaning
 the source directory first. If there is no sign this was intended,
 consider reporting it as an upstream bug as it may be a DFSG violation.
