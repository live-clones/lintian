Tag: typelib-missing-gir-depends
Severity: warning
Check: desktop/gnome/gir
Explanation: GObject-Introspection binary typelibs
 (<code>Foo-23.typelib</code>) can depend on other typelibs. To generate
 appropriate dependencies in the binary package, they must have
 <code>Depends: ${gir:Depends}</code> in the control file.
See-Also: /usr/share/doc/gobject-introspection/policy.txt
