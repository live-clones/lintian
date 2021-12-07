Tag: dir-or-file-in-srv
Severity: error
Check: files/hierarchy/standard
Explanation: Debian packages should install nothing into <code>/srv</code>.
 .
 The specification for <code>/srv</code> states that its use is at the
 discretion of the local administrator. No package should rely on a
 particular layout.
 .
 Debian packages that install files there are unable to adjust to any local
 policy. They force a local administrator's hand.
 .
 If a package wishes to place data below <code>/srv</code>, it must do so in
 a way that permits the local administrator to select the folder (for
 example, through post-install configuration, setup scripts,
 <code>debconf</code> promps, or similar).
See-Also:
 filesystem-hierarchy srvdataforservicesprovidedbysystem
