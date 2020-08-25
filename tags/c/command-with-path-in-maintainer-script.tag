Tag: command-with-path-in-maintainer-script
Severity: warning
Check: scripts
Explanation: The indicated program run in a maintainer script has a prepended
 path. Programs called from maintainer scripts normally should not have a
 path prepended. dpkg ensures that the PATH is set to a reasonable value,
 and prepending a path may prevent the local administrator from using a
 replacement version of a command for some local reason.
 .
 If the path is used to test a program for existence, please use <code>if
 which $program > /dev/null; then …</code>.
 .
 If you intend to override this tag, please make sure that you are in
 control of the installation path of the according program and that
 you won't forget to change this maintainer script, too, if you ever
 move that program around.
See-Also: policy 6.1, devref 6.4, Bug#769845, Bug#807695,
 https://lists.debian.org/debian-devel/2014/11/msg00044.html
