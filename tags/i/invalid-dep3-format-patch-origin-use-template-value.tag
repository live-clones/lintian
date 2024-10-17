Tag: invalid-dep3-format-patch-origin-use-template-value
Severity: error
Check: debian/patches/dep3
Explanation: "Origin:" field contains template value, should be changed to
 appropriate value.
 .
 "Origin:" field should point URL or the relevant commit identifier, and
 optionally add prefixed single keyword to categorize the origin (one of those:
 "upstream", "backport", "vendor" and "other") followed by a comma and a space.
 .
  - upstream: In the case of a patch cherry-picked from the upstream VCS
  - backport: In the case of an upstream patch that had to be modified to apply
              on the current version
  - vendor: Debian or another distribution vendor, such as Fedora or Ubuntu
  - other: All other kind of patches. For example, a user-created patch grabbed
           in a BTS should be categorized as "other"
 .
 e.g. "Origin: upstream, https://git.example.com/12345/commit/?id=123abc456def"
      "Origin: upstream, commit:123abc456def"
      "Origin: backport, https://git.example.com/12345/commit/?id=123abc456def"
      "Origin: vendor, https://git.launchpad.net/foobar/commit/?id=123abc456def"
      "Origin: other, https://example.com/forum/12345/?msg=abc456"
 .
 It would be better to point URL if VCS web interface is possible, not
 commit identifier.
 .
See-Also: https://dep-team.pages.debian.net/deps/dep3/
