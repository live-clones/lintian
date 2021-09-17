Tag: systemd-service-in-odd-location
Severity: error
Check: systemd
Explanation: The package ships a systemd service file in a location outside
 <code>/usr/lib/systemd/system/</code>
 .
 Systemd in Debian looks for unit files in <code>/usr/lib/systemd/system/</code>.
 <code>/lib/systemd/system/</code> and <code>/etc/systemd/system</code>, but the
 first location is now standard in Debian.
 .
 System administrators have the possibility to override service files (or in newer
 systemd versions, parts of them) by placing files in <code>/etc/systemd/system</code>.
 The canonical location for service files in Debian is <code>/usr/lib/systemd/system/</code>.
See-Also:
 Bug#992465,
 Bug#987989,
 https://salsa.debian.org/debian/debhelper/-/commit/d70caa69c64b124e3611c967cfab93aef48346d8,
 https://lists.debian.org/debian-devel/2021/08/msg00275.html
