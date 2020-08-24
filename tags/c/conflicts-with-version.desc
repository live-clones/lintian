Tag: conflicts-with-version
Severity: info
Check: fields/package-relations
See-Also: policy 7.4
Explanation: An earlier-than version clause is normally an indication that Breaks
 should be used instead of Conflicts. Breaks is a weaker requirement that
 provides the package manager more leeway to find a valid upgrade path.
 Conflicts should only be used if two packages can never be unpacked at
 the same time, or for some situations involving virtual packages (where a
 version clause is not appropriate). In particular, when moving files
 between packages, use Breaks plus Replaces, not Conflicts plus Replaces.
