# -*- perl -*- Lintian::Index::FileTypes
#
# Copyright (C) 2020-2021 Felix Lechner
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

package Lintian::Index::FileTypes;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Cwd;
use Unicode::UTF8 qw(encode_utf8 decode_utf8);

use Lintian::IPC::Run3 qw(xargs);

use Moo::Role;
use namespace::clean;

const my $EMPTY => q{};
const my $SPACE => q{ };
const my $COMMA => q{,};
const my $NEWLINE => qq{\n};

const my $KEEP_EMPTY_FIELDS => -1;
const my $GZIP_MAGIC_SIZE => 9;
const my $GZIP_MAGIC_BYTES => 0x1f8b;

=head1 NAME

Lintian::Index::FileTypes - determine file type via magic.

=head1 SYNOPSIS

    use Lintian::Index;

=head1 DESCRIPTION

Lintian::Index::FileTypes determine file type via magic.

=head1 INSTANCE METHODS

=over 4

=item add_file_types

=cut

sub add_file_types {
    my ($self) = @_;

    my $savedir = getcwd;
    chdir $self->basedir
      or die encode_utf8(
        $self->identifier . ': Cannot change to directory ' . $self->basedir);

    my $errors = $EMPTY;

    my @files = grep { $_->is_file } @{$self->sorted_list};
    my @names = map { $_->name } @files;

    my @command = qw(file --no-pad --print0 --print0 --);

    my %file_types;

    xargs(
        \@command,
        \@names,
        sub {
            my ($stdout, $stderr, $status, @partial) = @_;

            # ignore failures if possible; file returns non-zero and
            # "ERROR" on parse errors but output is still usable

            # undecoded split allows names with non UTF-8 bytes
            $stdout =~ s{ \0 $}{}x;

            my @lines = split(m{\0}, $stdout, $KEEP_EMPTY_FIELDS);

            unless (@lines % 2 == 0) {
                $errors
                  .= 'Did not get an even number lines from file command.'
                  . $NEWLINE;
                return;
            }

            while (defined(my $path = shift @lines)) {

                my $type = shift @lines;

                unless (length $path && length $type) {
                    $errors
                      .= "syntax error in file-info output: '$path' '$type'"
                      . $NEWLINE;
                    next;
                }

                # drop relative prefix, if present
                $path =~ s{^ [.]/ }{}x;

                $file_types{$path} = $self->adjust_type($path, $type);
            }

            return;
        });

    $_->file_type($file_types{$_->name}) for @files;

    chdir $savedir
      or die encode_utf8(
        $self->identifier . ": Cannot change to directory $savedir");

    return $errors;
}

=item adjust_type

=cut

# some files need to be corrected
sub adjust_type {
    my ($self, $name, $file_type) = @_;

    if ($name =~ m{ [.]gz $}ix && $file_type !~ /compressed/) {

        my $item = $self->lookup($name);

        die encode_utf8("Cannot find file $name in index")
          unless $item;

        my $buffer = $item->magic($GZIP_MAGIC_SIZE);
        if (length $buffer) {

            # translation of the unpack
            #  nn nn ,  NN NN NN NN, nn nn, cc     - bytes read
            #  $magic,  __ __ __ __, __ __, $comp  - variables
            my ($magic, undef, undef, $compression) = unpack('nNnc', $buffer);

            # gzip file magic
            if ($magic == $GZIP_MAGIC_BYTES) {

                my $augment = 'gzip compressed data';

                # 2 for max compression; RFC1952 suggests this is a
                # flag and not a value, hence bit operation
                $augment .= $COMMA . $SPACE . 'max compression'
                  if $compression & 2;

                return $file_type . $COMMA . $SPACE . $augment;
            }
        }
    }

    # some TFMs are categorized as gzip, see Bug#963589
    return 'data'
      if $name =~ m{ [.]tfm $}ix
      && $file_type =~ /gzip compressed data/;

    return $file_type;
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
