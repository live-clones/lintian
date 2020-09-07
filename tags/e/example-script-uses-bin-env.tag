Tag: example-script-uses-bin-env
Severity: info
Check: scripts
Explanation: This example script uses /bin/env as its interpreter (used to find
 the actual interpreter on the user's path). There is no /bin/env on
 Debian systems; env is instead installed as /usr/bin/env. Usually, the
 path to env in the script should be changed.
