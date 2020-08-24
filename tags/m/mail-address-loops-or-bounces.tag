Tag: mail-address-loops-or-bounces
Severity: error
Check: fields/mail-address
Renamed-From:
 maintainer-address-causes-mail-loops-or-bounces
 uploader-address-causes-mail-loops-or-bounces
Explanation: The contact's mail address either loops back to itself or is known
 to bounce.
 .
 Loops happen because an address is <tt>package@packages.debian.org</tt>
 or to <tt>package@packages.qa.debian.org</tt>. Bounces happen when the
 receipient, typically a mailing list, is known to bounce mails.
 .
 The mail address must accept messages from role accounts used to send
 automated mails regarding the package, including those from the bug
 tracking system.
See-Also: policy 3.3
