Tag: package-mixes-misc-and-dpi-fonts
Severity: warning
Check: desktop/x11
See-Also: policy 11.8.5
Explanation: This package contains both bitmapped fonts for a specific DPI
 (100dpi or 75dpi) and misc bitmapped fonts. These should not be combined
 in the same package. Instead, the misc bitmapped fonts should be
 provided in a separate package with <code>-misc</code> appended to its name.
