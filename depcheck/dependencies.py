#!/usr/bin/python

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

import package
from relation import Virtual
import version

# Create a dictionary of the available packages, including provided
# virtual packages.  The dictionary maps package names to versions.
def packagedict(packages):
    pkdict = {}
    for pk in packages.values():
	pkdict[pk['name']] = pk['version']
	for provided in pk['provides']:
	    if not pkdict.has_key(provided):
		pkdict[provided] = Virtual
    return pkdict

def satisfy(relations, pkdict):
    failed = []
    for rel in relations:
	needs = rel.satisfied_by(pkdict)
	if needs is None:
	    failed.append(rel)
    return failed
    # Future dreams: check if the depended-on packages don't conflict.

def failure(name, rels, singular, plural):
    use = singular
    if len(rels) > 1:
	use = plural
    deps = string.join(map(str, rels), ', ')
    return '%s: %s %s' % (name, use, deps)

def delete_relations(pk, relation, deletions):
    for rel in deletions:
	pk[relation].remove(rel)

def test_packages(packages):
    pkdict = packagedict(packages)
    warnings = []
    for pk in packages.values():
        if pk.has_key('depends'):
	    fl = satisfy(pk['depends'], pkdict)
	    if fl:
		warnings.append(failure(pk['name'], fl, 'dependency', 'dependencies'))
		delete_relations(pk, 'depends', fl)
        if pk.has_key('recommends'):
	    fl = satisfy(pk['recommends'], pkdict)
	    if fl:
		warnings.append(failure(pk['name'], fl, 'recommendation', 'recommendations'))
		delete_relations(pk, 'recommends', fl)
	if pk.has_key('pre-depends'):
	    fl = satisfy(pk['pre-depends'], pkdict)
	    if fl:
		warnings.append(failure(pk['name'], fl, 'pre-dependency', 'pre-dependencies'))
		delete_relations(pk, 'pre-depends', fl)
    warnings.sort()
    return warnings

def tosubtract(warning):
    return warning not in subtract

def print_warnings(warnings, header):
    warnings = filter(tosubtract, warnings)
    if len(warnings):
        print header + "\n"
	for warning in warnings:
	    print "  " + warning
        print ""


def test(packagefile):
    filter = ['package', 'version', 'depends', 'recommends', 'provides',
	      'pre-depends', 'priority', 'section']
    allpackages = package.parsepackages(open(packagefile), filter)
    priorities = {'required': {}, 'important': {}, 'standard': {},
		  'optional': {}, 'extra': {}}
    for pk in allpackages.values():
	priorities[pk['priority']][pk['name']] = pk

    packages = allpackages
    print_warnings(test_packages(packages),
                   "Cannot satisfy with packages in main:");

    # packages-in-base check moved up to here, because otherwise some
    # of them will show up as "Cannot satisfy with required packages".
    for pk in packages.keys():
	if packages[pk]['section'] != 'base':
	    del packages[pk]
    print_warnings(test_packages(packages),
                   "Cannot satisfy with packages in base:");

    packages = priorities['required']
    print_warnings(test_packages(packages),
                   "Cannot satisfy with required packages:");

    packages.update(priorities['important'])
    print_warnings(test_packages(packages),
                   "Cannot satisfy with important packages:");

    packages.update(priorities['standard'])
    print_warnings(test_packages(packages),
                   "Cannot satisfy with standard packages:");

    packages.update(priorities['optional'])
    print_warnings(test_packages(packages),
                   "Cannot satisfy with optional packages:");

    packages.update(priorities['extra'])
    print_warnings(test_packages(packages),
                   "Cannot satisfy with extra packages:");

    for pk in packages.keys():
	if packages[pk]['section'] == 'oldlibs':
	    del packages[pk]
    print_warnings(test_packages(packages),
                   "Cannot satisfy without packages in oldlibs:");

import sys

if len(sys.argv) == 3:
   subtract = []
   for line in open(sys.argv[2]).readlines():
     subtract.append(line[2:-1])
else:
   subtract = [];

   

if len(sys.argv) > 1:
   test(sys.argv[1])
else:
   test("/var/lib/dpkg/methods/ftp/Packages.hamm_main")
