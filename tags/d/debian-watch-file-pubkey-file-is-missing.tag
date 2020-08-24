Tag: debian-watch-file-pubkey-file-is-missing
Severity: error
Check: debian/watch
See-Also: uscan(1)
Explanation: This watch file verifies a cryptographic signature but
 the upstream public key is missing.
 .
 Please add upstream public keys in either
 debian/upstream/signing-key.asc or
 debian/upstream/signing-key.pgp.
