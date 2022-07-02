Tag: typelib-missing-gir-depends
Severity: warning
Check: desktop/gnome/gir
Explanation: GObject-Introspection compiled typelibs
 (<code>Foo-23.typelib</code>) can depend on other typelibs. To generate
 appropriate dependencies in the binary package, they must specify
 <code>Depends: ${gir:Depends}</code> in the <code>control</code> file.
See-Also:
 /usr/share/doc/gobject-introspection/policy.txt
