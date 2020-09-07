Tag: dir-or-file-in-srv
Severity: error
Check: files/hierarchy/standard
Explanation: Debian packages should not install into <code>/srv</code>. The
 specification of <code>/srv</code> states that its structure is at the
 discretion of the local administrator and no package should rely on any
 particular structure. Debian packages that install files directly into
 <code>/srv</code> can't adjust for local policy about its structure and in
 essence force a particular structure.
 .
 If a package wishes to put its data in <code>/srv</code>, it must do this in
 a way that allows the local administrator to specify and preserve their
 chosen directory structure (such as through post-install configuration,
 setup scripts, debconf prompting, etc.).
See-Also: fhs srvdataforservicesprovidedbysystem
