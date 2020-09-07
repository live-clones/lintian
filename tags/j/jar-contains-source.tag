Tag: jar-contains-source
Severity: warning
Check: languages/java
Explanation: The package ships the specified Jar file containing a
 <code>.java</code> file alongside a corresponding <code>.class</code> file.
 .
 This wastes disk space as the source is always available via <code>apt
 source</code>.
 .
 Please ensure that the specified <code>.java</code> files are not shipped in
 the Jar file.
See-Also: java-policy 2.4
