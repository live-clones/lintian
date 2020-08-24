Tag: executable-in-usr-lib
Severity: pedantic
Check: files/permissions/usr-lib
Explanation: The package ships an executable file in /usr/lib.
 .
 Please move the file to <tt>/usr/libexec</tt>.
 .
 Debian adopted the Filesystem Hierarchy Specification (FHS)
 version 3.0 starting with our policy revision 4.1.5. The
 FHS 3.0 describes <tt>/usr/libexec</tt>. Please use that
 location for executables.
See-Also: policy 9.1.1,
 https://refspecs.linuxfoundation.org/FHS_3.0/fhs/ch04s07.html,
 Bug#954149
