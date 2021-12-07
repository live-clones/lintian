Tag: desktop-entry-limited-to-environments
Severity: info
Check: menu-format
Explanation: This desktop entry limits the environments in which it is shown
 via the <code>OnlyShowIn</code> field but lists multiple environments therein.
 .
 The condition often indicates that a desktop file was written under the
 assumption that only GNOME, KDE, or Xfce are being used, and that the desktop
 file is in fact intended to exclude one of them.
 .
 That the application from desktop environments like LXDE where it may work
 fine. If this application supports any desktop environment except specific
 ones, it would be better to instead specify the unsupported environments via
 the <code>NotShowIn</code> field.
