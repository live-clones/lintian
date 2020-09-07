Tag: package-installs-apt-keyring
Severity: error
Check: apt
See-Also: apt-key(8)
Explanation: Debian packages should not install files under
 <code>/etc/apt/trusted.gpg.d/</code> or install an
 <code>/etc/apt/trusted.gpg</code> file.
 .
 Trusted keyrings are under the control of the local administrator and
 packages should not override local administrator choices.
 .
 Packages whose names end in <code>-apt-source</code> or
 <code>-archive-keyring</code> are permitted to install such files.
