Tag: ldconfig-escape
Severity: info
Check: files/hierarchy/links
Renamed-From:
 breakout-link
Explanation: The named link is located in the load path for the dynamic
 linker but points outside that group of folders.
 .
 Packages should install public shared libraries into the load path.
See-Also:
 Bug#243158,
 Bug#964111,
 Bug#971707,
 Bug#968525
