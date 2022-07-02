Tag: non-wm-module-in-wm-modules-menu-section
Severity: error
Check: menu-format
Explanation: The <code>menu</code> item is in the section for <code>FVWM Modules</code>
 or <code>Window Maker</code> but a window manager as a prerequisite via the
 <code>needs</code> key in the <code>menu</code> file.
 .
 Modules for Fvwm should list <code>needs="fvwmmodule"</code>.
 .
 Modules for WindowMaker should list <code>needs="wmmaker"</code>.
