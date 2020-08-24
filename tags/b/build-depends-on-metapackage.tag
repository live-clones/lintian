Tag: build-depends-on-metapackage
Severity: error
Check: fields/package-relations
Explanation: Packages must not build-depend on metapackages.
 .
 Metapackages such as xorg, xorg-dev, x-window-system,
 x-window-system-dev and x-window-system-core exist only for the
 benefit of users and should not be used in package build
 dependencies.
See-Also: https://wiki.debian.org/Lintian/Tags/depends-on-metapackage
