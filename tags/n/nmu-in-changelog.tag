Tag: nmu-in-changelog
Severity: warning
Check: nmu
Renamed-From: changelog-should-not-mention-nmu
Explanation: The first line of the changelog entry for this package appears to
 indicate it is a non-maintainer upload (by including either that string
 or the string "NMU" and not saying that it's an acknowledgement), but the
 changelog indicates the person making this release is one of the
 maintainers.
 .
 If this was intended to be an NMU, do not add yourself as a maintainer or
 uploader.
 .
 If this is *not* intended to be a NMU, remove the string "NMU".
 .
 If you are trying to acknowledge a NMU, you might have misspelled the
 string lintian expects in such cases. Rephrase your changelog entry to
 say "Acknowledge NMU" literally.
