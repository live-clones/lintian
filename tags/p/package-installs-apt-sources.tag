Tag: package-installs-apt-sources
Severity: error
Check: apt
See-Also: sources.list(5)
Explanation: Debian packages should not install files under
 <code>/etc/apt/sources.list.d/</code> or install an
 <code>/etc/apt/sources.list</code> file.
 . 
 The selection of installation sources is under the control of the
 local administrator. Packages are generally not allowed to change
 the administrator's choices.
 .
 As a limited exception for the convenience of administrators,
 packages whose names end in the clearly named
 <code>-apt-source</code> are permitted to install such files.
Renamed-From:
 package-install-apt-sources
