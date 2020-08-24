Tag: lib-recommends-documentation
Severity: warning
Check: fields/package-relations
Explanation: The given package appears to be a library package, but it recommends
 a documentation package. Doing this can pull in unwanted (and often
 large) documentation packages since recommends are installed by default
 and library packages are pulled by applications that use them. Users
 usually only care about the library documentation if they're developing
 against the library, not just using it, so the development package should
 recommend the documentation instead. If there is no development package
 (for modules for scripting languages, for example), consider Suggests
 instead of Recommends.
