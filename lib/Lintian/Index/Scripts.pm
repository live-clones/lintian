# -*- perl -*- Lintian::Index::Scripts
#
# Copyright © 2020 Felix Lechner
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.

package Lintian::Index::Scripts;

use strict;
use warnings;
use autodie;

use Path::Tiny;

use constant EMPTY => q{};
use constant SPACE => q{ };
use constant NEWLINE => qq{\n};

use Moo::Role;
use namespace::clean;

=head1 NAME

Lintian::Index::Scripts - information about scripts.

=head1 SYNOPSIS

    use Lintian::Processable;
    my $processable = Lintian::Processable::Binary->new;

=head1 DESCRIPTION

Lintian::Index::Scripts information about scripts.

=head1 INSTANCE METHODS

=over 4

=item add_scripts

=cut

sub add_scripts {
    my ($self, $pkg, $type, $dir) = @_;

    my %scripts;

    my @files
      = grep { $_->is_regular_file && $_->is_open_ok } $self->sorted_list;
    foreach my $file (@files) {

        # skip lincity data files; magic: #!#!#!
        next
          if $file->magic(6) eq '#!#!#!';

        # no shebang => no script
        my $interpreter = $file->get_interpreter;
        next
          unless defined $interpreter;

        # remove comment, if any
        my ($stripped) = ($interpreter =~ /^([^#]*)/);

        my %record;

        # remove /usr/bin/env; get a true boolean success value #943724
        my $calls_env = 0 + ($stripped =~ s{^/usr/bin/env\s+}{},);
        $record{calls_env} = $calls_env;

        # get base command without options
        $stripped =~ s/\s++ .++ \Z//xsm;

        $record{interpreter} = $stripped || $interpreter;

        $scripts{$file->name} = \%record;
    }

    $_->script($scripts{$_->name}) for @files;

    return;
}

=back

=head1 AUTHOR

Originally written by Felix Lechner <felix.lechner@lease-up.com> for
Lintian.

=head1 SEE ALSO

lintian(1)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
