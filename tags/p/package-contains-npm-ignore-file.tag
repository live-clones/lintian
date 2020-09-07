Tag: package-contains-npm-ignore-file
Severity: error
Check: files/names
Explanation: The package ships an <code>.npmignore</code> file. It is a
 configuration file for the <code>Node.js</code> package manager.
 It is not needed in a Debian package.
 .
 The file tells the <code>npm</code> command to keep files out of
 a <code>node</code> package. Please remove it from your package.
