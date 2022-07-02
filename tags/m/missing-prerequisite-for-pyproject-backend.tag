Tag: missing-prerequisite-for-pyproject-backend
Severity: info
Check: languages/python
Explanation: <code>pybuild</code> now supports building with PEP-517 standard
 interfaces natively. These sources could be built using <code>pybuild</code>'s
 generic <code>pyproject</code> plugin and the named build backend.
 .
 Please declare both named prerequisites in <code>Build-Depends</code>. You will
 need both the generic <code>pybuild-plugin-pyproject</code> as well as the
 specific one to the named backend. It is usually <code>python3-${backend}</code>.
 .
 No changes are required if you are using <code>pybuild</code>'s dedicated
 <code>flit</code> plugin, although that plugin will eventually be deprecated in
 favor of the generic <code>pyproject</code> plugin mentioned above.
