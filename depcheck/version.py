# This module defines the immutable Version type. 
# Initialize it with Version(string).  It defines attributes
# epoch, upstream, and debian.
# Comparison operations are defined on Versions and follow the same rules
# as dpkg.

# Copyright (C) 1998 Richard Braakman
#
# This program is free software.  It is distributed under the terms of
# the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any
# later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, you can find it on the World Wide
# Web at http://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
# MA 02111-1307, USA.

import string
import re

# TODO:  Is the regexp very slow?  Find out.  It could be simplified
#        at the cost of some extra string slicing by the caller.

# python can be just as incomprehensible as perl!
version_format = re.compile(r"^(\d+:)?([\w][\w+.:\-]*?)(-[\w+.]+)?$")

# The regexp above breaks down into three parts:
#   (\d+:)?            Optional epoch  
#   ([\w][\w+.:\-]*?)  Upstream version number
#   (-[\w+.]+)?        Optional Debian revision
# The *? notation at the end of the upstream version number means the
# regexp engine should attempt a minimum-length match, rather than
# maximum-length.  This prevents the upstream-version pattern from
# gobbling up the Debian revision.

# A non-numeric sequence followed by a numeric sequence.
# The comparison code uses it to consume the version string according
# to the algorithm in the Policy manual, two steps at a time.
compare_format = re.compile(r"([^\d]*)(\d*)")

# An alphabetic sequence followed by a non-alphabetic sequence.
# This way, the non-numeric parts are divided into parts just
# like the entire version string is.
alph_compare_format = re.compile(r"([a-zA-Z]*)([^a-zA-Z]*)")

# Compare non-numeric parts of version strings x and y.
# It differs from the normal cmp, because non-alphabetic characters
# must sort newer than alphabetic ones.
def alphcmp(x, y):
    while len(x) > 0 and len(y) > 0:
        # The match is guaranteed not to fail, because the regexp can match
        # a zero-length string.
        (xalph, xnonalph) = alph_compare_format.match(x).groups()
        (yalph, ynonalph) = alph_compare_format.match(y).groups()
        if xalph == yalph:
	    if xnonalph == ynonalph:
	        x = x[len(xalph) + len(xnonalph):]
	        y = y[len(yalph) + len(ynonalph):]
 	    else:
	        return cmp(xnonalph, ynonalph)
        else:
	    common = min(len(xalph), len(yalph))
	    if xalph[:common] == yalph[:common]:
		if len(xalph) == common:
		    if xnonalph == '':
			return -1  # y is the longer string
		    else:
			return 1   # xnonalph will sort newer than yalph's tail
		else:
		    if ynonalph == '':
			return 1   # x is the longer string
		    else:
			return -1  # ynonalph will sort newer than xalph's tail
	    else:
		return cmp(xalph[:common], yalph[:common])

    # One of the strings is exhausted.  The longer string counts as newer.
    return cmp(len(x), len(y))
	    

# Compare the version strings x and y.  Return positive if x is
# newer than y, and negative if x is older than y.  The caller
# guarantees that they are not equal.
def versioncmp(x, y):
    while len(x) > 0 and len(y) > 0:
        # The match is guaranteed not to fail, because the regexp can match
        # a zero-length string.
        (xnondigit, xdigit) = compare_format.match(x).groups()
        (ynondigit, ydigit) = compare_format.match(y).groups()
        if xnondigit == ynondigit:
	    if xdigit == ydigit:
	        x = x[len(xnondigit) + len(xdigit):]
	        y = y[len(ynondigit) + len(ydigit):]
            # Count an empty digit string as zero.  (i.e. 1.1 versus 1.)
	    elif xdigit == '':
	        return cmp(0, string.atoi(ydigit))
            elif ydigit == '':
	        return cmp(string.atoi(xdigit), 0)
 	    else:
	        return cmp(string.atoi(xdigit), string.atoi(ydigit))
        else:
	    return alphcmp(xnondigit, ynondigit)

    # One of the strings is exhausted.  The longer string counts as newer.
    return cmp(len(x), len(y))

compare_cache = {}

def cache_versioncmp(x, y):
    if compare_cache.has_key((x, y)):
	return compare_cache[(x, y)]
    c = versioncmp(x, y)
    compare_cache[(x, y)] = c
    compare_cache[(y, x)] = -c
    return c
	
# A version is an immutable object.  It is created with Version(string)
# and is not changed thereafter.  This is not enforced.
class Version:
    # A Version object is defined by an epoch (stored in self.epoch
    # as an integer), an upstream version (stored in self.upstream as
    # a string), and a debian revision (stroed in self.debian as
    # a string).
    # self.debian may be None to indicate that the version number does
    # not have a Debian revision.
    def __init__(self, version):
        # See Policy manual, chapter 4.
	match = version_format.match(version)
	if not match:
	    raise ValueError, version
        (epoch, upstream, debian) = match.group(1, 2, 3)
	if epoch:
	    # slice off the colon
	    self.epoch = string.atoi(epoch[:-1])
	else:
	    self.epoch = 0
	self.upstream = upstream
	if debian:
	    # slice off the leading hyphen
	    self.debian = debian[1:]
	else:
	    self.debian = None

    # This function compares two versions.  We use the earlier/later
    # relationship defined in the policy manual as our ordering
    # relationship.  Thus, the function should return a negative
    # number if self is earlier than other, zero if they are equal,
    # and a positive number if self is later than other.
    def __cmp__(self, other):
	if self.epoch == other.epoch:
	    if self.upstream == other.upstream:
		if self.debian == other.debian:
		    return 0
		# "The absence of a <debian_revision> compares earlier than
		# the presence of one". (Policy manual chapter 4)
		elif self.debian and not other.debian:
		    return 1
		elif not self.debian and other.debian:
		    return -1
		else:
		    return cache_versioncmp(self.debian, other.debian)
	    else:
		return cache_versioncmp(self.upstream, other.upstream)
	else:
	    return cmp(self.epoch, other.epoch)

    # Return a good hash value when this object is used as a key
    # in a dictionary.  Only immutable objects should define a
    # hash function.
    def __hash__(self):
	return hash(self.epoch) ^ hash(self.upstream) ^ hash(self.debian)

    # This should return a string representation of this object.
    # We represent a version string by recombining the epoch,
    # upstream version, and debian revision.  
    def __str__(self):
        # We normally leave out an epoch of 0, but we do add it if
        # the upstream version contains a colon (:), in order to
        # keep it a valid version string.
	if self.epoch != 0 or string.find(self.upstream, ':') >= 0:
	    if self.debian:
		return '%d:%s-%s' % (self.epoch, self.upstream, self.debian)
	    else:
		return '%d:%s' % (self.epoch, self.upstream)
	elif self.debian:
	    return self.upstream + '-' + self.debian
	else:
	    return self.upstream

    # This should return a string that is a valid Python expression
    # for recreating this value.  It is the "official" representation.
    # Useful for debugging.
    def __repr__(self):
	return 'Version(' + `str(self)` + ')'
	
    # Cheap comparison, when only equality is asked for.
    def equals(self, other):
	return self.upstream == other.upstream and \
	       self.debian == other.debian and \
	       self.epoch == other.epoch

version_cache = {}

def make(version):
    if version_cache.has_key(version):
	return version_cache[version]
    else:
        v = Version(version)
	version_cache[version] = v
	return v
