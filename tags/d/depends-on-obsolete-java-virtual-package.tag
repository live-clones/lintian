Tag: depends-on-obsolete-java-virtual-package
Severity: warning
Check: fields/package-relations
Explanation: The package (build-)depends on a numbered Java virtual package
 such as <code>java17-runtime-headless</code> or <code>java21-sdk</code>.
 .
 Since openjdk-17 the OpenJDK packages provide versioned virtual packages
 (for example <code>java-runtime-headless (= 25)</code>), and since openjdk-24
 they no longer provide the numbered ones. Such a dependency can't be
 satisfied by openjdk-24 or later and should be replaced by the versioned
 form:
 .
  javaNN-runtime-headless =&gt; java-runtime-headless (&gt;= NN)
  javaNN-runtime =&gt; java-runtime (&gt;= NN)
  javaNN-sdk-headless =&gt; java-sdk-headless (&gt;= NN)
  javaNN-sdk =&gt; java-sdk (&gt;= NN)
