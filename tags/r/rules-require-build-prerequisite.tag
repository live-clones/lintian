Tag: rules-require-build-prerequisite
Severity: error
Check: debian/rules
Renamed-From:
 missing-build-dependency
 missing-python-build-dependency
Explanation:
 The code in <code>debian/rules</code> requires a prerequisite
 that is not presently listed in the package's <code>Build-Depends</code>.
 .
 In the special case of Python, affected packages should <code>Build-Depend</code>
 on one of <code>python3</code>, <code>python3-all</code>, <code>python3-dev</code>,
 or <code>python3-all-dev</code>. Which one depends on whether a package supports
 multiple Python versions, and also whether the package builds Python modules
 or uses Python only as part of the build process.
 .
 Packages that depend on a specific Python version may build-depend
 on any appropriate <code>pythonX.Y</code> or <code>pythonX.Y-dev</code> package
 instead.
 .
 The condition you see in the context is not a recommendation on what to add. If
 you see a list, more than likely only one member is needed to make this tag go
 away. You probably also do not need the <code>:any</code> multiarch acceptor,
 if you see one.
See-Also: policy 4.2
