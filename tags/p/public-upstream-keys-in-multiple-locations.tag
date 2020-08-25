Tag: public-upstream-keys-in-multiple-locations
Severity: info
Check: debian/upstream/signing-key
See-Also: uscan(1)
Explanation: The source package contains public upstream signing keys
 (or keyrings) in multiple locations. This situation is potentially
 confusing for uscan(1) or any other tool hoping to verify the
 integrity and authenticity of upstream sources.
 .
 Please remove all keys (or keyrings) except one at the recommended
 location <code>debian/upstream/signing-key.asc</code>.
