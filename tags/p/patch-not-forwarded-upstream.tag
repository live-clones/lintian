Tag: patch-not-forwarded-upstream
Severity: info
Check: debian/patches/dep3
Renamed-From: send-patch
Explanation: According to the DEP-3 headers, this patch has not been forwarded
 upstream.
 .
 Please forward the patch and try to have it included in upstream's version
 control system. If the patch is not suitable for that, please mention
 <code>not-needed</code> in the <code>Forwarded</code> field of the patch
 header.
 .
 If the patch was actually taken from upstream, please prefix the
 <code>Origin</code> field information with <code>upstream</code> or
 <code>backport</code>, as documented in the DEP-3. For example:
 .
     Origin: upstream, https://github.com/zim-desktop-wiki/zim-desktop-wiki/commit/d33286c75b623cfb249c627b0c348be62e6377c9.patch
See-Also: social contract item 2,
 developer-reference 3.1.4,
 debian-policy 4.3,
 Bug#755153,
 https://dep-team.pages.debian.net/deps/dep3/
