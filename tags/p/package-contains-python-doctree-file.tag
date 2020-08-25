Tag: package-contains-python-doctree-file
Severity: warning
Check: files/names
Explanation: This package appears to contain a pickled cache of reStructuredText
 (*.rst) documentation in a <code>.doctree</code> file.
 .
 These are not needed to display the documentation correctly and as they can
 contain absolute build paths can affect the reproducibility of the package.
 .
 Either prevent the installation of the <code>.doctree</code> file (or parent
 <code>doctrees</code> directory if there is one) or pass the <code>-d</code>
 option to <code>sphinx-build(1)</code> to create the caches elsewhere.
 .
 For example:
 .
   override_dh_auto_build:
           dh_auto_build
           PYTHONPATH=. sphinx-build -bman docs/ -d debian/doctrees docs/build/html
           PYTHONPATH=. sphinx-build -bhtml docs/ -d debian/doctrees docs/build/html
 .
   override_dh_auto_clean:
           dh_auto_clean
           rm -rf debian/doctrees
See-Also: http://sphinx-doc.org/invocation.html#cmdoption-sphinx-build-d
