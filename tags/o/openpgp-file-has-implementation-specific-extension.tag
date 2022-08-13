Tag: openpgp-file-has-implementation-specific-extension
Severity: pedantic
Check: files/openpgp
Explanation: The package includes an OpenPGP file with an implementation
 specific extension such as <code>.gpg</code>, instead of the more correct
 and neutral <code>.pgp</code>.
 .
 The specification for this format is called OpenPGP, and the extension name
 that is short and considered implementation neutral is <code>.pgp</code>.
 While currently the GnuPG project is widely used and one of the most known
 OpenPGP implementations, using an extension after its name is detrimental
 to other alternative implementations, when a better more neutral name can
 be used instead.
 .
 Note that many of these files are referenced externally, and as such should
 be considered an interface. Make sure to create backward compatibility
 symlinks for a smooth transition.
See-Also:
 https://www.openpgp.org/,
 https://www.rfc-editor.org/rfc/rfc4880
