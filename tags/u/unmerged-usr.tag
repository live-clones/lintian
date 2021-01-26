Tag: unmerged-usr
Severity: classification
Check: files/hierarchy/merged-usr
Explanation: The named file is being installed in a legacy location.
 Modern Debian systems install this file under <code>/usr</code>.
 .
 Please move this file to a suitable place under the "merged /usr"
 scheme. Please consult the provided references as to where that
 might be.
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
