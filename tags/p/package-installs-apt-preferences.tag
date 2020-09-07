Tag: package-installs-apt-preferences
Severity: error
Check: apt
See-Also: apt_preferences(5)
Explanation: Debian packages should not install files under <code>/etc/apt/preferences.d/</code> or install an /etc/apt/preferences file.
 This directory is under the control of the local administrator.
 .
 Package should not override local administrator choices.
Renamed-From:
 package-install-apt-preferences
