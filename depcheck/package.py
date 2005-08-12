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
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

import string
import regex

import version
import relation

bad_field = 'Bad field value'

defaults = {'depends': [], 'recommends': [], 'suggests': [], 'pre-depends': [],
            'conflicts': [], 'replaces': [], 'provides': [],
            'essential': 0, 'distribution': 'main', 'architecture': 'all',
            'description': '', 'synopsis': ''}

relationships = ['depends', 'recommends', 'suggests', 'pre-depends',
		 'conflicts', 'replaces']

# The Package class models a read-only dictionary that is initialized
# by feeding it a paragraph of control information.
# Some translation is done on the field names:
# 'package'     ->  'name'
# 'source'      ->  'sourcepackage' and 'sourceversion'
# 'description' ->  'synopsis' and 'description'
# 'section'     ->  'distribution' and 'section'
class Package:
    def __init__(self):
	self.fields = {}

    def __len__(self):
	return len(self.fields)

    # Look up a field in this package.
    def __getitem__(self, key):
        if self.fields.has_key(key):
	    return self.fields[key]
	# If it is not defined, return the default value for that field.
        if defaults.has_key(key):
	    return defaults[key]
	# Special defaults
	if key == 'sourcepackage':
	    return self['name']
	if key == 'sourceversion':
	    return self['version']
	# If there is no default, try again with a lowercase version
	# of the field name.
        lcase = string.lower(key)
	if lcase != key:
	    return self[lcase]
	raise KeyError, key

    # Define some standard dictionary methods
    def keys(self):   return self.fields.keys()
    def items(self):  return self.fields.items()
    def values(self): return self.fields.values()
    def has_key(self, key):  return self.fields.has_key(key)

    def parsefield(self, field, fieldval):
	# Perform translations on field and fieldval
	if field == 'package':
	    field = 'name'
	elif field == 'version':
	    fieldval = version.make(fieldval)
	elif field == 'architecture':
	    fieldval = string.split(fieldval)
	    if len(fieldval) == 1:
		fieldval = fieldval[0]
	elif field == 'source':
 	    field = 'sourcepackage'
	    splitsource = string.split(fieldval)
	    if (len(splitsource) > 1):
		if splitsource[1][0] != '(' \
		   or splitsource[1][-1] != ')':
		    raise ValueError, fieldval
		fieldval = splitsource[0]
		self.fields['sourceversion'] = version.make(splitsource[1][1:-1])
	elif field in relationships:
	    fieldval = map(relation.parse, string.split(fieldval, ','))
	elif field == 'provides':
	    # I will assume that the alternates construct is
	    # not allowed in the Provides: header.
	    fieldval = string.split(fieldval, ', ')
	elif field == 'description':
	    i = string.find(fieldval, '\n')
	    if i >= 0:
		self.fields['description'] = fieldval[i+1:]
		fieldval = string.strip(fieldval[:i])
	elif field == 'essential':
	    if fieldval == 'yes':
		fieldval = 1
	    elif fieldval != 'no':
		raise ValueError, fieldval
	    else:
		fieldval = 0 
	elif field == 'section':
	    i = string.find(fieldval, '/')
	    if i >= 0:
		self.fields['distribution'] = fieldval[:i]
		fieldval = fieldval[i+1:]
	elif field == 'installed-size':
	    fieldval = string.atoi(fieldval)
	elif field == 'size':
	    fieldval = string.atoi(fieldval)

	self.fields[field] = fieldval

    # This function accepts a list of "field: value" strings, 
    # with continuation lines already folded into the values.
    # "filter" is an array of header fields (lowercase) to parse.
    # If it is None, parse all fields.
    def parseparagraph(self, lines, filter=None):
	for line in lines:
	    idx = string.find(line, ':')
	    if idx < 0:
	        raise bad_field, line
	    field = string.lower(line[:idx])
	    if not filter or field in filter:
		try:
		    self.parsefield(field, string.strip(line[idx+1:]))
		except:
		     raise bad_field, line

def parsepackages(infile, filter=None):
    packages = {}
    paragraph = []
    while 1:
        line = infile.readline()
	if len(line) == 0:
	    break 
	elif line[0] == ' ' or line[0] == '\t':
	    paragraph[-1] = paragraph[-1] + line
	elif line[0] == '\n':
	    pk = Package()
	    pk.parseparagraph(paragraph, filter)
	    packages[pk['name']] = pk
	    paragraph = []
	else:
	    paragraph.append(line)
    return packages
