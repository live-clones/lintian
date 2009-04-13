#!/usr/bin/perl

true and exec '/bin/sh', $0;
__END__ 2>/dev/null || true

# Test to make sure all the collection scripts listed in the Needs-Info fields
# of {checks,collection}/*desc do exist

# Perl's prove, the shell way :)

####################
#    Copyright (C) 2009 by Raphael Geissert <atomo64@gmail.com>
#
#
#    This file is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 2 of the License, or
#    (at your option) any later version.
#
#    This file is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this file.  If not, see <http://www.gnu.org/licenses/>.
####################

set -e

LINTIAN_ROOT=${LINTIAN_ROOT:=$(pwd)}

descs="$(find "$LINTIAN_ROOT/collection/" "$LINTIAN_ROOT/checks/" \
	-name '*desc' -type f)"

total="$(echo "$descs" | wc -l)"

printf "1..%d\n" "$total"

c=1

echo "$descs" |
while read desc; do
    needs="$(sed -n 's/^Needs-Info:\s*//g;T;s/,/ /g;s/\s+/ /g;p' "$desc")"
    missing=
    for coll in $needs; do
	[ -f "$LINTIAN_ROOT/collection/$coll" ] || {
	    missing="$missing
#   Missing collection script '$coll' detected
#   at $desc"
	}
    done
    [ -z "$missing" ] || printf 'not '
    printf 'ok %d - %s has valid needs-info\n' "$c" "${desc#$LINTIAN_ROOT/}"
    [ -z "$missing" ] || printf '%s\n' "$missing" >&2
    c=$((c+1))
done

exit
