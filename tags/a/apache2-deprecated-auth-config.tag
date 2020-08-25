Tag: apache2-deprecated-auth-config
Severity: warning
Check: apache2
Explanation: The package is using some of the deprecated authentication configuration
 directives Order, Satisfy, Allow, Deny, &lt;Limit&gt; or &lt;LimitExcept&gt;
 .
 These do not integrate well with the new authorization scheme of Apache
 2.4 and, in the case of &lt;Limit&gt; and &lt;LimitExcept&gt; have confusing
 semantics. The configuration directives should be replaced with a suitable
 combination of &lt;RequireAll&gt;, &lt;RequireAny&gt;, Require all, Require local,
 Require ip, and Require method.
 .
 Alternatively, the offending lines can be wrapped between
 &lt;IfModule !mod&lowbar;authz&lowbar;core.c&gt; ... &lt;/IfModule&gt; or
 &lt;IfVersion &lt; 2.3&gt; ... &lt;/IfVersion&gt; directives.
