Tag: uses-gbp-conf
Severity: classification
Check: version-control/git-buildpackage
Explanation: The package appears to use git-buildpackage (gbp) for package
 maintenance, as indicated by the presence of a gbp.conf configuration file.
 .
 This is an informational tag to help classify packages using git-buildpackage
 for maintenance. Git-buildpackage is a suite of tools that helps with
 maintaining Debian packages in Git repositories.
 .
 Note that as git-buildpackage does not mandate ony one specific workflow, the
 mere presence of a gbp.conf file alone does not necessarily mean the package
 is fully maintained with git-buildpackage. Package maintainers might be
 using gbp only for cloning a repository, for importing new upstream versions
 to get the git branches pulled and updated correctly, to manage patch queue
 git branches or to automate debian/changelog updates based on git
 commits.
