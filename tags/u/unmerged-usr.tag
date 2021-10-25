Tag: unmerged-usr
Severity: classification
Check: files/hierarchy/merged-usr
Explanation: The named file is being installed in a legacy location.
 Many competing distributions install this file under <code>/usr</code>.
 Debian would like to do the same, but the best way to get there is
 presently unclear.
 .
 Please coordinate with the release team before you change this path to
 the new location. There is a growing body of evidence that uncoordinated
 action by individual package maintainers or teams may not be the best
 path forward.
 .
 Debian's Technical Committee voted on February 1, 2021 that the
 <code>bookworm</code> release should support only the merged-usr root
 filesystem layout, thus dropping support for the non-merged-usr layout.
See-Also:
 https://wiki.debian.org/UsrMerge,
 https://wiki.debian.org/Teams/Dpkg/MergedUsr,
 Bug#978636,
 https://lists.debian.org/debian-devel/2020/11/#00232,
 https://lists.debian.org/debian-devel/2020/12/#00386,
 https://lists.debian.org/debian-devel-announce/2019/03/msg00001.html,
 https://rusty.ozlabs.org/?p=236,
 https://www.linux-magazine.com/Issues/2019/228/Debian-usr-Merge,
 https://lwn.net/Articles/773342/,
 https://www.freedesktop.org/wiki/Software/systemd/TheCaseForTheUsrMerge/
