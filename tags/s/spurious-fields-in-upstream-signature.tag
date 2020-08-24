Tag: spurious-fields-in-upstream-signature
Severity: info
Check: upstream-signature
Explanation: The packaging includes a detached upstream signature file that contains
 spurious fields like <tt>Comment:</tt> or <tt>Version:</tt>. They are
 sometimes added by <tt>gpg --enarmor</tt>, especially if you have an older
 version. Modern versions only add a <tt>Comment:</tt> field.
 .
 Please generate the signature with <tt>gpg --armor --detach-sig</tt> using a
 modern version instead.
