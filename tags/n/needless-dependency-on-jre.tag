Tag: needless-dependency-on-jre
Severity: warning
Check: fields/package-relations
Explanation: The package appear to be a Java library and depending on one
 or more JRE/JDK packages. As of 05 Apr 2010, the Java Policy no
 longer mandates that Java libraries depend on Java Runtimes.
 .
 If the library package ships executables along with the library,
 then please consider making this an application package or move the
 binaries to a (new) application package.
 .
 If there is otherwise a valid reason for this dependency, please override
 the tag.
See-Also: https://lists.debian.org/debian-devel-changes/2010/04/msg00774.html,
 Bug#227587
