Tag: classpath-contains-relative-path
Severity: warning
Check: languages/java
Explanation: The classpath listed in the jar file refers to a potential
 missing jar file. This could be the remnants of a build-time
 classpath that are not relevant for a JAR bundled in a Debian
 package.
 .
 Alternatively, the classpath may be correct, but the package is
 lacking a jar file or a symlink to it.
 .
 Note, Lintian assumes that all (relative) classpaths pointing to
 /usr/share/java/ (but not subdirs thereof) are satisfied by
 dependencies as long as there is at least one strong libX-java
 dependency.
