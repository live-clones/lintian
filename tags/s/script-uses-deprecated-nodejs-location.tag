Tag: script-uses-deprecated-nodejs-location
Severity: warning
Check: scripts
Explanation: You used <code>/usr/bin/nodejs</code> or <code>/usr/bin/env nodejs</code> as an
 interpreter for a script.
 .
 The <code>/usr/bin/node</code> binary was previously provided by
 <code>ax25-node</code> and packages were required to use <code>/usr/bin/nodejs</code>
 instead. <code>ax25-node</code> has since been removed from the archive and the
 <code>nodejs</code> package now ships the <code>/usr/bin/node</code> binary to match
 the rest of the Node.js ecosystem.
 .
 Please update your package to use the <code>node</code> variant.
See-Also: Bug#614907, Bug#862051
