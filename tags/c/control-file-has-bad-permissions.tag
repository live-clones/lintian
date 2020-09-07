Tag: control-file-has-bad-permissions
Severity: error
Check: control-files
See-Also: policy 10.9
Explanation: The <code>config</code>, <code>postinst</code>, <code>postrm</code>,
 <code>preinst</code>, and <code>prerm</code> control files should use mode 0755;
 all other control files should use 0644.
