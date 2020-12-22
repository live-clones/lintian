Tag: postrm-does-not-call-updaterc.d-for-init.d-script
Severity: error
Check: init-d
Explanation: An <code>/etc/init.d</code> script which has been registered in the
 <code>postinst</code> script is not de-registered in the
 <code>postrm</code> script.
See-Also: policy 9.3.3.1
