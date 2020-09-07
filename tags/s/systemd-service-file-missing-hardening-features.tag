Tag: systemd-service-file-missing-hardening-features
Severity: pedantic
Experimental: yes
Check: systemd
Explanation: The specified systemd <code>.service</code> file does not appear to
 enable any hardening options.
 .
 systemd has support for many security-oriented features such as
 isolating services from the network, private <code>/tmp</code> directories,
 as well as control over making directories appear read-only or even
 inaccessible, etc.
 .
 Please consider supporting some options, collaborating upstream where
 necessary about any potential changes.
See-Also: systemd.service(5), http://0pointer.de/blog/projects/security.html
