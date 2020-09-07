Tag: depends-on-python-minimal
Severity: error
Check: fields/package-relations
Explanation: The python-minimal package (and versioned variants thereof) exists
 only to possibly become an Essential package. Depending on it is always
 an error since it should never be installed without python. If it
 becomes Essential, there is no need to depend on it, and until then,
 packages that require Python must depend on python.
