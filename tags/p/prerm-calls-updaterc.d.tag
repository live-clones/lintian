Tag: prerm-calls-updaterc.d
Severity: error
Check: init-d
Explanation: The <code>prerm</code> package calls <code>update-rc.d</code>. Instead,
 you should call it in the <code>postrm</code> script.
See-Also: policy 9.3.3.1
