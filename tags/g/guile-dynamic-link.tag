Tag: guile-dynamic-link
Severity: classification
Check: languages/guile/dynamic-link
Explanation: Guile tries to load this shared library via a Scheme expression like
 <code>(define libglib (dynamic-link "libglib-2.0"))</code>.
See-Also:
 Bug#999738
