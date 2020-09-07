Tag: non-wm-module-in-wm-modules-menu-section
Severity: error
Check: menu-format
Explanation: The menu item is in the FVWM Modules or Window Maker section but
 does not declare that it needs a specific window manager (using the needs
 key in the menu file). Modules for Fvwm should have needs="fvwmmodule".
 Modules for WindowMaker should have needs="wmmaker".
