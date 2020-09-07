Tag: whitespace-after-continuation-character
Severity: error
Check: menu-format
Explanation: The menu item is split up over 2 or more lines using '\' at the end of
 the line to join them together. However, there is some whitespace after
 the '\' character, which is not guaranteed to be handled correctly.
 The '\' should be at the end of the line.
