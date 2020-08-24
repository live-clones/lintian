Tag: desktop-entry-limited-to-environments
Severity: info
Check: menu-format
Explanation: This desktop entry uses OnlyShowIn to limit the environments in
 which it's displayed but lists multiple environments. This is often a
 sign of a desktop file written assuming that only GNOME, KDE, and Xfce
 are in use and the desktop file intended to exclude one of them. This
 unintentionally hides the application from desktop environments such as
 LXDE where it would work fine. If this application supports any desktop
 environment except some specific ones, it should list the unsupported
 environments in the NotShowIn key instead.
