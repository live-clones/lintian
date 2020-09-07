Tag: udev-rule-missing-uaccess
Severity: warning
Check: udev
See-Also: https://wiki.debian.org/USB/GadgetSetup
Explanation: The package set up a device for user access without using the
 uaccess tag. Some udev rules get the same effect using other markers
 enabling console user access using rules in
 /lib/udev/rules.d/70-uaccess.rules. Others should specify
 TAG+="uaccess" in the udev rule.
