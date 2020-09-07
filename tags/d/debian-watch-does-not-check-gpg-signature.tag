Tag: debian-watch-does-not-check-gpg-signature
Severity: pedantic
Check: debian/watch
Experimental: yes
See-Also: uscan(1)
Explanation: This watch file does not specify a means to verify the upstream
 tarball using a cryptographic signature.
 .
 If upstream distributions provides such signatures, please use the
 <code>pgpsigurlmangle</code> options in this watch file's <code>opts=</code> to
 generate the URL of an upstream GPG signature. This signature is
 automatically downloaded and verified against a keyring stored in
 <code>debian/upstream/signing-key.asc</code>
 .
 Of course, not all upstreams provide such signatures but you could
 request them as a way of verifying that no third party has modified the
 code after its release (projects such as phpmyadmin, unrealircd, and
 proftpd have suffered from this kind of attack).
Renamed-From:
 debian-watch-may-check-gpg-signature
