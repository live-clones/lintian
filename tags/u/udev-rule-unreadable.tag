Tag: udev-rule-unreadable
Severity: error
Check: udev
See-Also: https://wiki.debian.org/USB/GadgetSetup
Explanation: The udev rule entry should be a file
 The package contain a non-file in /lib/udev/rules.d/. The directory
 should only contain readable files.
