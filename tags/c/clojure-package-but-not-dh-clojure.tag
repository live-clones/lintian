Tag: clojure-package-but-not-dh-clojure
Severity: warning
Check: languages/clojure/dh-clojure
Explanation: This Clojure source package build-depends on <code>leiningen</code>
 but does not build using <code>dh-clojure</code>.
 .
 To ensure consistent packaging and testing practices, please make sure to
 build using <code>dh-clojure</code>.
See-Also: dh-clojure(7), dh-clojure-lein(7)
