Tag: architecture-escape
Severity: info
Check: files/hierarchy/links
Explanation: The named link is located in an architecture-specific load
 path for the dynamic linker but points to a general folder in the path.
 .
 Packages should install public shared libraries into an
 architecture-specific load path instead of using a link.
See-Also:
 Bug#243158,
 Bug#964111,
 Bug#971707,
 Bug#968525
