Tag: add-component-copyright
Severity: info
Check: debian/copyright/dep5/components
Explanation: The sources ship an extra <code>orig</code> component, but the
 named <code>debian/copyright</code> file lacks a separate entry for it.
 .
 Tarballs usually include a COPYING or LICENSE file, or a shipping  manifest
 of some kind. It is good practice to list those license terms separately in
 our copyright files.
See-Also:
 uscan(1),
 Bug#915181,
 Bug#915384
