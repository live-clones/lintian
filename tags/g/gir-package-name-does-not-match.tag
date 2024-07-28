Tag: gir-package-name-does-not-match
Severity: warning
Check: desktop/gnome/gir
Explanation: Development packages that contain public
 GObject-Introspection XML files
 (<code>/usr/share/gir-1.0/Foo-23.gir</code> or
 <code>/usr/lib/${DEB_HOST_MULTIARCH}/gir-1.0/Foo-23.gir</code>)
 should be named <code>gir1.2-foo-23-dev</code> if the GIR XML is the only
 content of the package, or should have a versioned <code>Provides</code> for
 <code>gir1.2-foo-23-dev (= ${binary:Version})</code> if the package contains
 other development files.
 .
 Since gobject-introspection 1.78.1-6 (Debian trixie),
 the recommended way to populate the <code>Provides</code> fields is to use
 debhelper and dh_girepository, via the gir addon or the dh-sequence-gir
 virtual package, and add <code>Provides: ${gir:Provides}</code> to
 packages that contain public GIR XML.
 .
 For example, <code>libgtk-3-dev</code> contains <code>Gtk-3.0.gir</code>,
 <code>Gdk-3.0.gir</code> and <code>GdkX11-3.0.gir</code>,
 so it should have
 <code>Provides: gir1.2-gtk-3.0-dev</code>,
 <code>Provides: gir1.2-gdk-3.0-dev</code> and
 <code>Provides: gir1.2-gdkx11-3.0-dev</code>.
See-Also:
 /usr/share/doc/gobject-introspection/policy.txt
