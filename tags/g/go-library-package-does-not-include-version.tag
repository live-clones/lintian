Tag: go-library-package-does-not-include-version
Severity: warning
Check: languages/golang/module-path
Explanation: This Golang package contains a versioned suffix <code>/vN</code>
 in <code>go.mod</code> but the name of the library package does not include
 <code>-vN-dev</code> as suffix.
See-Also: https://wiki.debian.org/Teams/DebianGoTeam/ModuleAwareBuilds
