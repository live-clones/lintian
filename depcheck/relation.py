# This module defines package relationships.
# It exports two special "version" values: Virtual and Any.
# A Virtual version never matches a versioned conflict or dependency.
# An Any version always matches a versioned conflict or dependency.

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

import version

# The two special "version" values.  All empty lists are unique,
# so these statements initialize them to unique values.
Virtual = []
Any = []

# The basic relationship: a single package name.
# Its name is stored in the name attribute.
class SimpleRelation:
    def __init__(self, package):
	self.name = package

    def __str__(self):
	return self.name

    def __repr__(self):
	return 'SimpleRelation(' + `self.name` + ')'

    def satisfied(self, packagename, version):
	return packagename == self.name

    def satisfied_by(self, packages):
	if packages.has_key(self.name):
	    return self.name
	return None

    def packagenames(self):
	return [self.name]

# A package name with a version check.
# The package name is stored in the name attribute.
# The relation is stored as a string in the relationstring attribute,
# and as a comparison function in the relation attribute.
# The version to compare to is stored in the version attribute.
class VersionedRelation:
    def __init__(self, package, relation, version):
	self.name = package
	self.version = version
	self.relationstring = relation
	if relation == '<' or relation == '<=':
	    self.relation = lessthan
	elif relation == '>' or relation == '>=':
	    self.relation = greaterthan
	elif relation == '=':
	    self.relation = equalversion
	elif relation == '>>':
	    self.relation = strictgreater
	elif relation == '<<':
	    self.relation = strictless
	else:
	    raise ValueError, 'relation: ' + relation

    def __str__(self):
	return '%s (%s %s)' % (self.name, self.relationstring, self.version)

    def __repr__(self):
	return 'VersionedRelation(' + `self.name` + ', ' + \
               `self.relationstring` + ', ' + `self.version` + ')'

    # version can be the special values Virtual or Any, in addition
    # to a normal Version instance.
    def satisfied(self, packagename, version):
	if packagename != self.name or version is Virtual:
	    return 0
        if version is Any:
	    return 1
	return self.relation(version, self.version)

    def satisfied_by(self, packages):
	version = packages.get(self.name)
	if version is not None and self.satisfied(self.name, version):
	    return self.name
	return None

    def packagenames(self):
	return [self.name]

# Relations joined with the "alternatives" operator, i.e. foo | bar.
# This class just stores the joined relations as a sequence.
class AltRelation:
    def __init__(self, relationlist):
	self.relations = relationlist

    def __str__(self):
	return string.join(map(str, self.relations), ' | ')

    def __repr__(self):
	return 'AltRelation(' + `self.relations` + ')'

    def satisfied(self, packagename, version):
	for rel in self.relations:
	    if rel.satisfied(packagename, version):
		return 1
	return 0

    def satisfied_by(self, packages):
	rv = []
	for rel in self.relations:
	    sb = rel.satisfied_by(packages)
	    if sb is not None and rv.count(sb) == 0:
		rv.append(sb)
	if len(rv) > 0:
	    return rv
	return None

    def packagenames(self):
	return reduce(lambda x, y: x + y.packagenames(), self.relations, [])

def parsealt(str):
    i = string.find(str, '(')
    if i == -1:
	return SimpleRelation(string.strip(str))
    packagename = string.strip(str[:i])
    j = string.find(str, ')')
    relver = string.strip(str[i+1:j])
    if relver[1] == '<' or relver[1] == '=' or relver[1] == '>':
	return VersionedRelation(packagename, relver[:2],
				 version.make(string.strip(relver[2:])))
    else:
	return VersionedRelation(packagename, relver[:1],
				 version.make(string.strip(relver[1:])))

def parse(str):
    alts = map(parsealt, string.split(str, '|'))
    if len(alts) > 1:
	return AltRelation(alts)
    return alts[0]

# Possible values for the relation attribute
def strictless(x, y):
    return x < y

def lessthan(x, y):
    return x <= y

def equalversion(x, y):
    return x.equals(y)

def greaterthan(x, y):
    return x >= y

def strictgreater(x, y):
    return x > y 

