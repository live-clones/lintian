Tag: explicitly-armored-upstream-signature
Severity: warning
Check: upstream-signature
Explanation: The packaging includes a detached upstream signature file that was armored
 explicitly using <code>gpg --enarmor</code>.  That is likely an error.
 .
 Please generate the signature with <code>gpg --armor --detach-sig</code> instead.
