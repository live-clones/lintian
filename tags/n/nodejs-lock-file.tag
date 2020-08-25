Tag: nodejs-lock-file
Severity: error
Check: languages/javascript/nodejs
Explanation: package-lock.json is automatically generated for any operations where
 npm modifies either the node&lowbar;modules tree, or package.json. It
 describes the exact tree that was generated, such that subsequent
 installs are able to generate identical trees, regardless of
 intermediate dependency updates.
 .
 These information are useless from a debian point of view, because
 version are managed by dpkg.
 .
 Moreover, package-lock.json feature to pin to some version
 dependencies is a anti feature of the debian way of managing package,
 and could lead to security problems in the likely case of debian
 solving security problems by patching instead of upgrading.
