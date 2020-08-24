Tag: doubly-armored-upstream-signature
Severity: error
Check: upstream-signature
Explanation: The packaging includes a detached upstream signature file that was armored
 twice (or more) using <tt>gpg --enarmor</tt>.  That is an error.
 .
 Please armor the signature just once. You can also use standard tools such as
 <tt>gpg --armor --detach-sig</tt>.
