Tag: executable-in-usr-lib
Severity: pedantic
Experimental: yes
Check: files/permissions/usr-lib
Explanation: The package ships an executable file in /usr/lib.
 .
 Please move the file to <code>/usr/libexec</code>.
 .
 Debian adopted the Filesystem Hierarchy Specification (FHS)
 version 3.0 starting with our policy revision 4.1.5. The
 FHS 3.0 describes <code>/usr/libexec</code>. Please use that
 location for executables.
See-Also: policy 9.1.1,
 https://refspecs.linuxfoundation.org/FHS_3.0/fhs/ch04s07.html,
 Bug#954149

Screen: emacs/elpa/scripts
Advocates: David Bremner <bremner@debian.org>
Reason: The <code>emacsen-common</code> package places installation
 and removal scripts, which for ELPA packages are executable,
 in the folder <code>/usr/lib/emacsen-common/packages</code>.
 .
 About four hundred installation packages are affected. All of
 them declare <code>emacsen-common</code> as an installation
 prerequisite.
See-Also:
 Bug#974175,
 Bug#954149
