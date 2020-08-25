Tag: gir-missing-typelib-dependency
Severity: warning
Check: desktop/gnome/gir
Explanation: Development packages that contain GObject-Introspection XML files
 (<code>/usr/share/gir-1.0/Foo-23.gir</code>) must depend on the package
 containing the corresponding binary typelib, which is conventionally named
 <code>gir1.2-foo-23</code>. The dependency must be strictly versioned
 (for example <code>gir1.2-foo-23 (= ${binary:Version})</code> when using
 debhelper).
 .
 If multiple typelibs are shipped in the same package, then that package
 should have versioned <code>Provides</code> for the names that would have been
 used for separate packages. In this case, Lintian does not emit this tag
 when a group of binary packages from the same source is checked together.
 .
 For example, <code>libgtk-3-dev</code> contains <code>Gtk-3.0.gir</code>,
 <code>Gdk-3.0.gir</code> and <code>GdkX11-3.0.gir</code>.
 <code>gir1.2-gtk-3.0</code> contains all three corresponding typelibs,
 so it is sufficient for <code>libgtk-3-dev</code> to depend on
 <code>gir1.2-gtk-3.0</code>. Giving <code>gir1.2-gtk-3.0</code> <code>Provides</code>
 entries for <code>gir1.2-gdk-3.0 (= ${binary:Version})</code>
 and <code>gir1.2-gdkx11-3.0 (= ${binary:Version})</code> signals this
 situation to Lintian.
See-Also: /usr/share/doc/gobject-introspection/policy.txt
