Tag: adduser-with-home-var-run
Severity: warning
Check: maintainer-scripts/adduser
Explanation: {pre,post}inst script calls adduser --home /var/run, should be /run.
 Examples for such packages include pesign, pulseaudio and openssh-server.
See-Also: Bug#760422
