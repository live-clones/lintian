Tag: file-directly-in-usr-share
Severity: error
Check: files/hierarchy/standard
Explanation: Packages should not install files directly in <tt>/usr/share</tt>,
 i.e., without a subdirectory.
 .
 You should either create a subdirectory <tt>/usr/share/...</tt> for your
 package or place the file in <tt>/usr/share/misc</tt>.
