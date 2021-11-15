Tag: static-link-time-optimization
Severity: info
Check: libraries/static/link-time-optimization
Explanation:
 The named member of the static library ships ELF sections that indicate the
 use of link-time-optimization (LTO). The use of LTO in static objects is
 usually a bug.
 .
 In the milder case, the library will work but is larger than needed. The more
 serious case is indicated by the distinct tag <code>no-code-sections</code>.
 Those libraries cannot work in Debian.
 .
 An object file shown here was usually built with the command-line option
 <code>-flto=auto</code>.
See-Also:
 https://gcc.gnu.org/wiki/LinkTimeOptimization,
 http://hubicka.blogspot.com/2014/04/linktime-optimization-in-gcc-2-firefox.html,
 Bug#963057
