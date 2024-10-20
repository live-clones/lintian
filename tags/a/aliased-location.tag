Tag: aliased-location
Severity: error
Check: files/hierarchy/standard
Explanation: The package installs into an aliased location.
 Since Debian trixie, the <code>base-files</code> package sets up symbolic
 links such as <code>/bin</code> pointing to <code>usr/bin</code>. Using the
 former paths triggers undefined behaviour in the <code>dpkg</code> package
 manager. It treats e.g. <code>/bin/sh</code> and <code>/usr/bin/sh</code> as
 two distinct filesystem objects and does not notice that operations on either
 affect the other. Therefore, packages must no longer install files into such
 locations and must install them to the corresponding location below
 <code>usr/</code> instead. References to such files do not have to be updated
 as all packages may rely on their files being accessible via the aliased
 locations at all times. The requirement is only imposed on the contents of
 the <code>data.tar</code> of a binary package.
See-Also:
 debian-policy 10.1 #1074014
