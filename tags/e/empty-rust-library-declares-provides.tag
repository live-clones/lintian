Tag: empty-rust-library-declares-provides
Severity: error
Check: languages/rust
Explanation: For some time, Rust libraries used empty installation packages
 with long Provides lines in their control files to deal with peculiarities
 in Rust packaging. It is no longer considered acceptable because it strains
 our archive infrastructure.
 .
 Rust packages should not be empty and merely declare a Provides control
 field. Instead, please merge such packages into the main installation
 package. When using <code>debcargo</code>, this can usually be achieved by
 adding <code>collapse_features = true</code> to the
 <code>debcargo.toml</code> file.
 .
 You can see some examples here:
 .
     - https://sources.debian.org/src/rust-dbus/0.9.0-2/debian/control/
     - https://sources.debian.org/src/rust-x11rb/0.7.0-1/debian/control/
 .
 The decision to burden the Rust packaging team with that extra step was
 made after weighing all possible alternatives.
See-Also:
 Bug#942898, Bug#945542,
 http://meetbot.debian.net/debian-rust/2020/debian-rust.2020-10-28-18.58.log.html#l-150
