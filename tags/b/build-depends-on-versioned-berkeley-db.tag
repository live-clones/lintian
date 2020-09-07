Tag: build-depends-on-versioned-berkeley-db
Severity: warning
Check: fields/package-relations
Explanation: The package build-depends on a versioned development package of
 Berkeley DB (libdbX.Y-dev) instead of versionless package
 (libdb-dev). Unfortunately this prevents binNMUs when default
 Berkeley DB version changes.
 .
 Unless the package absolutely have to depend on specific Berkeley DB
 version, it should build-depends on libdb-dev. For more information
 on the upgrade process, please see the references.
 .
 The package can usually be made Berkeley DB version agnostic by the
 following steps:
 .
  1. note the version of Berkeley DB used to compile the package on build time
  2. on first install copy the used version to active version
  3. on upgrades compare the versions and if they differ do the upgrade procedure
 .
 If you are unsure you can contact Berkeley DB maintainer, who would be
 glad to help.
 .
 Should the package have a legitimate reason for using the versioned development
 package, please add an override.
See-Also: http://docs.oracle.com/cd/E17076_02/html/upgrading/upgrade_process.html
