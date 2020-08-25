Tag: git-patches-not-exported
Severity: error
Check: debian/source-dir
Explanation: The source package contains files in
 <code>debian/source/git-patches</code>. These patches should have been exported
 via the <code>quilt-patches-deb-export-hook</code> of <code>gitpkg</code>.
 .
 It does not look like the patches were exported for this source package.
 .
 You will see this tag when you generate a source package without
 <code>gitpkg</code> (or with a misconfigured version) unless the patches
 were exported manually.
 .
 See the above mentioned hook file (in <code>/usr/share/gitpkg/hooks</code>)
 for information on how to export patches manually.
