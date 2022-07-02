Tag: javalib-but-no-public-jars
Severity: info
Check: languages/java
Explanation: The name of the package suggests it contains a java library but
 the package does not ship any JAR files in <code>/usr/share/java</code>.
 .
 The java policy mandates that JAR files outside <code>/usr/share/java</code>
 are for private use.
See-Also:
 java-policy
