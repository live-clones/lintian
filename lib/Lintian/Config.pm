# Copyright (C) 2011 Niels Thykier <niels@thykier.net>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
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

## Represents a Lintian Config file
package Lintian::Config;

use strict;
use warnings;

use Carp qw(croak);

# Lintian::Config->new($opts)
#
# Creates an instance of Lintian::Config; each key in $opts
# specifies a valid option that may appear in the config file.
sub new {
    my ($type, $opts) = @_;
    my $self = {
        # Options set in the config
        'opts'          => {},
        # Options allowed in the config
        'allowed-opts'  => $opts,
    };
    bless $self, $type;
    return $self;
}

# $conf->read_file($file);
#
# Parses a config file.  Croaks if:
#  - there is a syntax error
#  - there is an unknown variable
#  - a variable appears twice in the file
# 
sub read_file {
    my ($self, $file) = @_;
    my $opts = $self->{'opts'};
    my $allowed = $self->{'allowed-opts'};
    open my $fd, '<', $file or croak "open $file: $!";
    while ( my $line = <$fd> ) {
        chomp($line);
        $line =~ s/\#.*+//o;
        next if $line =~ m/^\s*+$/o;
        if ($line =~ m/^\s*+(\S++)\s*+=\s*+(.*\S)\s*$/o){
            my ($var, $val) = ($1, $2);
            my $old;
            croak "$file: unknown variable (\"$var\") at line $."
                unless exists $allowed->{$var};
            $old = $opts->{$var};
            if (defined $old) {
                croak "$file: \"$var\" appears a second time at line $.";
            } else {
                $opts->{$var} = $val;
            }
        } else {
            croak "$file: syntax error at line $.";
        }
    }
    close $fd;
}

# $conf->get_variable($var[, $def]);
#
# Returns the value of $var if set by the config file
# If $var was not set, $def (or if absent, undef) is returned.
sub get_variable {
    my ($self, $var, $def) = @_;
    return $self->{'opts'}->{$var} if exists $self->{'opts'}->{$var};
    return $def;
}

