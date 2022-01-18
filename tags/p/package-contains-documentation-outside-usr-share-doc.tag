Tag: package-contains-documentation-outside-usr-share-doc
Severity: info
Check: documentation
Explanation: This package ships a documentation file outside /usr/share/doc
 Documentation files are normally installed inside <code>/usr/share/doc</code>.
 .
 If this file doesn't describe the contents or purpose of the directory
 it is in, please consider moving this file to <code>/usr/share/doc/</code>
 or maybe even removing it. If this file does describe the contents
 or purpose of the directory it is in, please add a lintian override.

Screen: python/egg/metadata
Advocates: Scott Kitterman <debian@kitterman.com>
Reason: The folders <code>XXX.dist-info/</code> and <code>XXX.egg-info/</code>
 hold metadata for Python modules. Those files are not documentation even though
 some of their names carry the <code>.txt</code> file extension.
 .
 Python modules can be both public and private.
See-Also:
 https://www.python.org/dev/peps/pep-0427/#the-dist-info-directory,
 https://www.python.org/dev/peps/pep-0376/#id16,
 https://www.python.org/dev/peps/pep-0610/,
 https://www.python.org/dev/peps/pep-0639/,
 https://setuptools.pypa.io/en/latest/deprecated/python_eggs.html,
 Bug#1003913
