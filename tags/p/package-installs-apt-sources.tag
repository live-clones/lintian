Tag: package-installs-apt-sources
Severity: error
Check: apt
See-Also: sources.list(5)
Explanation: Debian packages should not install files under
 <code>/etc/apt/sources.list.d/</code> or install an
 <code>/etc/apt/sources.list</code> file.
 . 
 Package sources are under the control of the local administrator and
 packages should not override local administrator choices.
 .
 Packages whose names end in <code>-apt-source</code> or
 <code>-archive-keyring</code> are permitted to install such files.
Renamed-From:
 package-install-apt-sources
