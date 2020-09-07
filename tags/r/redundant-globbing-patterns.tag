Tag: redundant-globbing-patterns
Severity: pedantic
Check: debian/copyright/dep5
Explanation: Two globbing patterns in the same <code>Files</code> section in
 debian/copyright match the same file.
 .
 This situation can occur when a narrow pattern should apply the same license
 as a broader pattern. Please create another <code>Files</code> section for the
 narrow pattern and place it below other patterns that compete for the same
 files.
See-Also: Bug#905747,
 https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
