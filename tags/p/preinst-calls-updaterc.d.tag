Tag: preinst-calls-updaterc.d
Severity: error
Check: init-d
Explanation: The <code>preinst</code> package calls <code>update-rc.d</code>. Instead,
 you should call it in the <code>postinst</code> script.
See-Also: policy 9.3.3.1
