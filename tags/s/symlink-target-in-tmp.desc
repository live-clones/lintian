Tag: symlink-target-in-tmp
Severity: error
Check: files/symbolic-links
Explanation: Packages must not set links with targets pointing into <tt>/tmp</tt> or
 <tt>/var/tmp</tt>. The File Hierarchy Standard specifies that such files
 may be removed by the administrator and that programs may not depend on
 any files in <tt>/tmp</tt> being preserved across invocations, which
 combined mean that it makes no sense to ship files in these directories.
See-Also: fhs tmptemporaryfiles, fhs vartmptemporaryfilespreservedbetwee
