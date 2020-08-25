Tag: diff-contains-hg-tags-file
Severity: warning
Check: cruft
Explanation: The Debian diff or native package contains an <code>.hgtags</code>
 file. This file is Mercurial metadata that should normally not be
 distributed. It stores hashes of tagged commits in a Mercurial
 repository and isn't therefore useful without the repository.
