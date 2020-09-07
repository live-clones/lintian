Tag: source-contains-hg-tags-file
Severity: pedantic
Check: cruft
Explanation: The upstream source contains an <code>.hgtags</code> file. This file is
 Mercurial metadata that should normally not be distributed. It stores
 hashes of tagged commits in a Mercurial repository and isn't therefore
 useful without the repository. You may want to report this as an
 upstream bug.
