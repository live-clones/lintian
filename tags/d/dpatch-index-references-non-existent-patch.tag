Tag: dpatch-index-references-non-existent-patch
Severity: error
Check: debian/patches/dpatch
Explanation: In the 00list file listing all your dpatches, you referenced a file
 that does not exist. This will lead to a fatal error when calling dpatch.
