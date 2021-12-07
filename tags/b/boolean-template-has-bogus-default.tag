Tag: boolean-template-has-bogus-default
Severity: error
Check: debian/debconf
Explanation: The <code>boolean</code> type in a Debconf template can have
 only one of two values: <code>true</code> or <code>false</code>. This
 template tries to use something else as the default value.
See-Also:
 debconf-specification 3.1,
 debconf-devel(7)
