Tag: duplicate-updaterc.d-calls-in-postrm
Severity: error
Check: init-d
Explanation: The <code>postrm</code> script calls <code>update-rc.d</code> several
 times for the same <code>/etc/init.d</code> script.
