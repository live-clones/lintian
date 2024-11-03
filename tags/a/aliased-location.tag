Tag: aliased-location
Severity: error
Check: files/hierarchy/standard
Explanation: This package installs files into an aliased location and should
 not be doing so.
 .
 Since Debian Trixie, the <code>base-files</code> package sets up symbolic links
 such as <code>/bin</code> pointing to <code>usr/bin</code>. Installing files in
 <code>/bin</code> directly thus triggers undefined behaviour in <code>dpkg</code>.
 .
 Packages must no longer install files into such locations and must install
 them to the corresponding location under <code>usr/</code> instead.
See-Also: debian-policy 10.1, Bug#1074014
