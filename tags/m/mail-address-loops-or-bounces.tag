Tag: mail-address-loops-or-bounces
Severity: error
Check: fields/mail-address
Renamed-From:
 maintainer-address-causes-mail-loops-or-bounces
 uploader-address-causes-mail-loops-or-bounces
Explanation: The contact's mail address either loops back to itself or is known
 to bounce.
 .
 Loops happen because an address is <code>package@packages.debian.org</code>
 or to <code>package@packages.qa.debian.org</code>. Bounces happen when the
 receipient, typically a mailing list, is known to bounce mails.
 .
 The mail address must accept messages from role accounts used to send
 automated mails regarding the package, including those from the bug
 tracking system.
See-Also: policy 3.3
