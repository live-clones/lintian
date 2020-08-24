Tag: duplicate-updaterc.d-calls-in-postrm
Severity: error
Check: init.d
Explanation: The <tt>postrm</tt> script calls <tt>update-rc.d</tt> several
 times for the same <tt>/etc/init.d</tt> script.
