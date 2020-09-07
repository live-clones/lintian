Tag: dir-or-file-in-var-www
Severity: error
Check: files/hierarchy/standard
See-Also: fhs thevarhierarchy
Explanation: Debian packages should not install files under <code>/var/www</code>.
 This is not one of the <code>/var</code> directories in the File Hierarchy
 Standard and is under the control of the local administrator. Packages
 should not assume that it is the document root for a web server; it is
 very common for users to change the default document root and packages
 should not assume that users will keep any particular setting.
 .
 Packages that want to make files available via an installed web server
 should instead put instructions for the local administrator in a
 README.Debian file and ideally include configuration fragments for common
 web servers such as Apache.
 .
 As an exception, packages are permitted to create the <code>/var/www</code>
 directory due to its past history as the default document root, but
 should at most copy over a default file in postinst for a new install.
 In this case, please add a Lintian override.
