Tag: prefer-uscan-symlink
Severity: pedantic
Experimental: yes
Check: debian/watch
Explanation: Please consider setting <code>USCAN_SYMLINK=rename</code> in your
 <code>~/.devscripts</code> configuration file instead of using the option
 <code>filenamemangle</code> in <code>debian/watch</code>.
 .
 Please check with your team before making changes to sources you maintain
 together. There are circumstances when the <code>filenamemangle</code> option
 is better.
See-Also:
 uscan(1)
