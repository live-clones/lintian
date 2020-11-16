Tag: malformed-override
Severity: error
Show-Always: yes
Check: lintian
See-Also: lintian 2.4.1
Explanation: Lintian discovered an override entry with an invalid format. An
 override entry should have the format:
 .
   [[&lt;package&gt;][ &lt;archlist&gt;][ &lt;type&gt;]:] &lt;tag&gt;[ &lt;extra&gt; ...]
 .
 where &lt;package&gt; is the package name, &lt;archlist&gt; is an
 architecture list, &lt;type&gt; specifies the package type (binary is the
 default), &lt;tag&gt; is the tag to override, and &lt;extra&gt; is any
  specific information for the particular tag to override.
