Tag: explicitly-armored-upstream-signature
Severity: warning
Check: upstream-signature
Explanation: The packaging includes a detached upstream signature file that was armored
 explicitly using <tt>gpg --enarmor</tt>.  That is likely an error.
 .
 Please generate the signature with <tt>gpg --armor --detach-sig</tt> instead.
