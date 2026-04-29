Tag: whitespace-after-continuation-character
Severity: error
Check: menu-format
Explanation: The menu item is split up over two or more continuation lines, but
 there is additional whitespace after the backslash (<code>&bsol;</code>) that
 indicates where lines should be joined together.
 .
 There is no guarantee that such additional whitespace is handled correctly.
 The backslash should be the end of the line.
