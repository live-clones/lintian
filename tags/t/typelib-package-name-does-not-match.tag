Tag: typelib-package-name-does-not-match
Severity: warning
Check: desktop/gnome/gir
Explanation: GObject-Introspection binary typelibs (<code>Foo-23.typelib</code>)
 should normally be made available in a package named gir1.2-foo-23.
 .
 If multiple typelibs are shipped in the same package, then that package
 should have versioned <code>Provides</code> for the names that would have been
 used for separate packages. This arrangement should only be used if the
 included typelibs' versions are expected to remain the same at all times.
 .
 For example, <code>gir1.2-gtk-3.0</code> is named for the <code>Gtk-3.0</code>
 typelib, but also contains the <code>Gdk-3.0</code> and <code>GdkX11-3.0</code>
 typelibs. It should have versioned <code>Provides</code> entries for
 <code>gir1.2-gdk-3.0 (= ${binary:Version})</code>
 and <code>gir1.2-gdkx11-3.0 (= ${binary:Version})</code> to indicate this.
See-Also: /usr/share/doc/gobject-introspection/policy.txt
