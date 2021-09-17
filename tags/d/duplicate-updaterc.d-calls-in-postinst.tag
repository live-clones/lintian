Tag: duplicate-updaterc.d-calls-in-postinst
Severity: error
Check: init-d
Explanation: The <code>postinst</code> script calls <code>update-rc.d</code> several
 times for the same <code>/etc/init.d</code> script.
