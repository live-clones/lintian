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
    chdir($self->basedir)
      or die 'Cannot change to directory ' . $self->basedir;

    my $errors = $EMPTY;

    my @files = grep { $_->is_file } @{$self->sorted_list};
    my @names = map { $_->name } @files;

    my @command = qw(file --no-pad --print0 --print0 --);

    my %fileinfo;

    xargs(
        \@command,
        \@names,
        sub {
            my ($stdout, $stderr, $status, @partial) = @_;

            # ignore failures if possible; file returns non-zero and
            # "ERROR" on parse errors but output is still usable

            # undecoded split allows names with non UTF-8 bytes
            $stdout =~ s/\0$//;

            my @lines = split(/\0/, $stdout, $KEEP_EMPTY_FIELDS);

            unless (@lines % 2 == 0) {
                $errors
                  .= 'Did not get an even number lines from file command.'
                  . $NEWLINE;
                return;
            }

            while(defined(my $path = shift @lines)) {

                my $type = shift @lines;

                unless (length $path && length $type) {
                    $errors
                      .= "syntax error in file-info output: '$path' '$type'"
                      . $NEWLINE;
                    next;
                }

                # drop relative prefix, if present
                $path =~ s{^\./}{};

                $fileinfo{$path} = $type;
            }

            return;
        });

    $_->file_info($fileinfo{$_->name}) for @files;

    # some files need to be corrected
    my @probably_compressed
      = grep { $_->name =~ /\.gz$/i && $_->file_info !~ /compressed/ } @files;

    for my $file (@probably_compressed) {

        my $buffer = $file->magic($GZIP_MAGIC_SIZE);
        next
          unless length $buffer;

        # translation of the unpack
        #  nn nn ,  NN NN NN NN, nn nn, cc     - bytes read
        #  $magic,  __ __ __ __, __ __, $comp  - variables
        my ($magic, undef, undef, $compression) = unpack('nNnc', $buffer);

        # gzip file magic
        next
          unless $magic == $GZIP_MAGIC_BYTES;

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

    chdir($savedir)
      or die encode_utf8("Cannot change to directory $savedir");

    return $errors;
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
