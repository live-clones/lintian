Tag: obsolete-vim-addon-manager
Severity: info
Check: vim/addons
Explanation: The package depends on <code>vim-addon-manager</code>. It
 is not needed anymore, if you use <code>debhelper</code>.
 .
 Please use <code>dh-vim-addon</code> instead. It will install
 <code>vim</code> files in the appropriate locations for you via
 the <code>:packadd</code> function available in <code>vim</code>
 version 8.
See-Also:
 dh_vim-addon(1)
