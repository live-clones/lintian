Tag: build-depends-on-obsolete-bootstrap
Severity: warning
Check: fields/package-relations
Explanation: The package build-depends on an unmaintained version of bootstrap.
 Upstream has EOL'ed boostrap 3 and 4 and is not providing public security
 patches for them. Projects should migrate to bootstrap version 5.
 Unfortunately, bootstrap 5 is not a drop-in replacement, so a simple switch on
 the build-dependency may not be enough. The following links provide some
 guidelines to help developers to migrate:
 .
 https://getbootstrap.com/docs/4.6/migration/
 https://getbootstrap.com/docs/5.3/migration/
