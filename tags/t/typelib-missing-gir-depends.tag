Tag: typelib-missing-gir-depends
Severity: error
Check: desktop/gnome/gir
Explanation: GObject-Introspection compiled typelibs
 (<code>Foo-23.typelib</code>) can depend on other typelibs. To generate
 appropriate dependencies in the binary package, they must specify
 <code>Depends: ${gir:Depends}</code> in the <code>control</code> file.
 .
 Similarly, <code>gir1.2-*-dev</code> packages containing GIR XML need
 <code>Depends: ${gir:Depends}</code> for appropriate dependencies.
See-Also:
 /usr/share/doc/gobject-introspection/policy.txt
