Tag: file-directly-in-usr-share
Severity: error
Check: files/hierarchy/standard
Explanation: Packages should not install files directly in <code>/usr/share</code>,
 i.e., without a subdirectory.
 .
 You should either create a subdirectory <code>/usr/share/...</code> for your
 package or place the file in <code>/usr/share/misc</code>.
