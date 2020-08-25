Tag: invalid-versioned-provides
Severity: error
Check: fields/package-relations
See-Also: policy 7.1, Bug#761219
Explanation: The package declares a provides relation with an invalid version
 operator (e.g. "&gt;=").
 .
 If a provides is versioned, it must use "=".
