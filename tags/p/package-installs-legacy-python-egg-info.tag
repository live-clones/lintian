Tag: package-installs-legacy-python-egg-info
Severity: info
Check: languages/python
Explanation: The package installs <code>.egg-info</code> directory.
 The modern replacement for <code>.egg-info</code> is <code>.dist-info</code>.
 That means the package was possibly built using the deprecated <code>setup.py
 install</code> mechanism. This should be usually converted to
 <code>pybuild-plugin-pyproject</code>.
See-Also: Bug#1121735,
 https://wiki.debian.org/Python/PybuildPluginPyproject,
 https://setuptools.pypa.io/en/stable/history.html#setup-install-deprecation-note
