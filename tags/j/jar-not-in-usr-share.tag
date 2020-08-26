Tag: jar-not-in-usr-share
Severity: warning
Check: languages/java
See-Also: java-policy 2.2, java-policy 2.3
Explanation: The classpath listed in some of the files references files outside
 of /usr/share, while all installed JAR files must be within
 /usr/share/java for libraries or /usr/share/*package* for JARs for
 private use.
 .
 The rationale is that jar files are in almost all cases architecture
 independent and therefore should be in /usr/share. If the jar file is
 truly architecture dependent or it cannot be moved since symlinked jar
 files are not accepted by the application, then please override this
 tag.
