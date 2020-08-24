Tag: udev-rule-missing-subsystem
Severity: warning
Check: udev
See-Also: https://wiki.debian.org/USB/GadgetSetup
Explanation: The package matches vendor/product IDs without specifying
 subsystem. The vendor/product IDs are subsystem specific. Matching
 rules using those should specify subsystem too, for example by using
 SUBSYSTEM=="usb" at the start of the matching rule.
