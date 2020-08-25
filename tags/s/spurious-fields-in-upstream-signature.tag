Tag: spurious-fields-in-upstream-signature
Severity: info
Check: upstream-signature
Explanation: The packaging includes a detached upstream signature file that contains
 spurious fields like <code>Comment:</code> or <code>Version:</code>. They are
 sometimes added by <code>gpg --enarmor</code>, especially if you have an older
 version. Modern versions only add a <code>Comment:</code> field.
 .
 Please generate the signature with <code>gpg --armor --detach-sig</code> using a
 modern version instead.
