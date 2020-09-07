Tag: dir-or-file-in-mnt
Severity: error
Check: files/hierarchy/standard
Explanation: Packages should not install into <code>/mnt</code>. The FHS states that
 this directory is reserved for the local system administrator for
 temporary mounts and that it must not be used by installation programs.
See-Also: fhs mntmountpointforatemporarilymount
