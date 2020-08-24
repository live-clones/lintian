Tag: needless-suggest-recommend-libservlet-java
Severity: warning
Check: fields/package-relations
Explanation: Package should not suggest or recommend libservlet-java
 Java servlets are only used in the context of a server (example: Tomcat or
 Jetty). This server will have this dependency and will take care of the
 loading of this package with the right libservlet.
 .
 Removing this dependency will fix this warning.
 .
 If there is otherwise a valid reason for this suggestion or recommendation,
 please override the tag.
