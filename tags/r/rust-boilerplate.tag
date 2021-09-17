Tag: rust-boilerplate
Severity: warning
Check: languages/rust
Explanation: The description for the named installable was created by
 a template in the Rust toolchain but not subsequently modified.
 .
 Please amend the default description provided by <code>debcargo</code>
 in <code>debian/control</code>.
 .
 Within the Rust toolchain you can also conveniently add something like
 the following example to <code>debian/debcargo.toml</code>:
 .
     [packages.bin]
     summary = "Command-line benchmarking tool"
     description = """
     Hyperfine is a benchmarking tool similar to 'time' that offers
     many additional features.  One can easily arrange repeated runs
     and export results in formats like CSV or JSON.
     """
See-Also:
 https://wiki.debian.org/Teams/RustPackaging
