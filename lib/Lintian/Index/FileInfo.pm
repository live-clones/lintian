# -*- perl -*- Lintian::Index::FileInfo
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

package Lintian::Index::FileInfo;

use v5.20;
use warnings;
use utf8;
use autodie;

use Const::Fast;
use Cwd;
use IPC::Run3;
use Unicode::UTF8 qw(encode_utf8 decode_utf8);

use Moo::Role;
use namespace::clean;

const my $EMPTY => q{};
const my $SPACE => q{ };
const my $COMMA => q{,};
const my $NULL => qq{\0};

=head1 NAME

Lintian::Index::FileInfo - determine file type via magic.

=head1 SYNOPSIS

    use Lintian::Index;

=head1 DESCRIPTION

Lintian::Index::FileInfo determine file type via magic.

=head1 INSTANCE METHODS

=over 4

=item add_fileinfo

=cut

sub add_fileinfo {
    my ($self) = @_;

    my $savedir = getcwd;
    chdir($self->basedir);

    my @files = grep { $_->is_file } $self->sorted_list;

    my $input = $EMPTY;
    $input .= $_->name . $NULL for @files;

    my $stdout;

    my @command = qw(
      xargs --null --no-run-if-empty
      file --no-pad --print0 --print0 --
    );

    # ignore failures; file returns non-zero on parse errors
    # output then contains "ERROR" messages but is still usable
    run3(\@command, \$input, \$stdout);

    # allow processing of file names with non UTF-8 bytes

    my %fileinfo;

    $stdout =~ s/\0$//;

    my @lines = split(/\0/, $stdout, -1);

    die encode_utf8('Did not get an even number lines from file command.')
      unless @lines % 2 == 0;

    while(defined(my $path = shift @lines)) {

        my $type = shift @lines;

        die encode_utf8("syntax error in file-info output: '$path' '$type'")
          unless length $path && length $type;

        # drop relative prefix, if present
        $path =~ s{^\./}{};

        $fileinfo{$path} = $type;
    }

    $_->file_info($fileinfo{$_->name}) for @files;

    # some files need to be corrected
    my @probably_compressed
      = grep { $_->name =~ /\.gz$/i && $_->file_info !~ /compressed/ } @files;

    for my $file (@probably_compressed) {

        my $buffer = $file->magic(9);
        next
          unless length $buffer;

        # translation of the unpack
        #  nn nn ,  NN NN NN NN, nn nn, cc     - bytes read
        #  $magic,  __ __ __ __, __ __, $comp  - variables
        my ($magic, undef, undef, $compression) = unpack('nNnc', $buffer);

        # gzip file magic
        next
          unless $magic == 0x1f8b;

        my $text = 'gzip compressed data';

        # 2 for max compression; RFC1952 suggests this is a
        # flag and not a value, hence bit operation
        $text .= $COMMA . $SPACE . 'max compression'
          if $compression & 2;

        my $new_type = $file->file_info . $COMMA . $SPACE . $text;
        $file->file_info($new_type);
    }

    # some TFMs are categorized as gzip, see Bug#963589
    my @not_gzip
      = grep { $_->name =~ /\.tfm$/i && $_->file_info =~ /gzip compressed data/ }
      @files;
    $_->file_info('data') for @not_gzip;

    chdir($savedir);

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
