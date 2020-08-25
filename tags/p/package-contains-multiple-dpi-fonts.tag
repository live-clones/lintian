Tag: package-contains-multiple-dpi-fonts
Severity: warning
Check: desktop/x11
See-Also: policy 11.8.5
Explanation: This package contains both 100dpi and 75dpi bitmapped fonts. Both
 versions should not be included in a single package. If both resolutions
 are available, they should be provided in separate binary packages with
 <code>-75dpi</code> or <code>-100dpi</code> appended to the package name for the
 corresponding fonts.
