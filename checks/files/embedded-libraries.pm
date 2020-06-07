# files/embedded-libraries -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz and Richard Braakman
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

package Lintian::files::embedded_libraries;

use v5.20;
use warnings;
use utf8;
use autodie;

use Lintian::SlidingWindow;

use Moo;
use namespace::clean;

with 'Lintian::Check';

# A list of known packaged Javascript libraries
# and the packages providing them
sub load_file_package_list_mapping {
    my ($datafile,$ext,$tagname,$reinside) = @_;

    my $mapping = Lintian::Data->new(
        $datafile,
        qr/\s*\~\~\s*/,
        sub {
            my ($pkg) = @_;

            # trim both ends
            $pkg =~ s/^\s+|\s+$//g;

            my $pkg_regexp = qr/^$pkg$/x;
            my @sliptline = split(/\s*\~\~/, $_[1], 2);
            my $file_regexp = $sliptline[0];

            # trim both ends
            $file_regexp =~ s/^\s+|\s+$//g;

            $file_regexp =~ s/\$EXT/$ext/g;
            my $recontents = $reinside;

            if (scalar(@sliptline) == 2) {
                my $contents = $sliptline[1];

                # trim both ends
                $contents =~ s/^\s+|\s+$//g;

                $recontents = qr/$contents/;
            }

            return {
                'pkg_re' => $pkg_regexp,
                'pkg' => $pkg,
                'match' => qr/$file_regexp/,
                'contents_re' => $recontents,
            };
        });

    return {
        'ext_regexp' => qr/$ext/x,
        'mapping' => $mapping,
        'ext' => $ext,
        'tag' => $tagname,
    };
}

my $JS_EXT
  = '(?:(?i)[-._]?(?:compiled|lite|min|pack(?:ed)?|prod|umd|yc)?\.(js|css)(?:\.gz)?)$';
my $PHP_EXT = '(?i)\.(?:php|inc|dtd)$';
my @FILE_PACKAGE_MAPPING = (
    load_file_package_list_mapping(
        'files/js-libraries',$JS_EXT,'embedded-javascript-library'
    ),
    load_file_package_list_mapping(
        'files/php-libraries',$PHP_EXT,'embedded-php-library'
    ),
    load_file_package_list_mapping(
        'files/pear-modules','(?i)\.php$',
        'embedded-pear-module',qr,pear[/.],
    ),
);

sub files {
    my ($self, $file) = @_;

    return
      unless $file->is_file;

    # ignore embedded jQuery libraries for Doxygen (#736360)
    unless (
           $file->basename eq 'jquery.js'
        && !$file->is_dir
        && defined$self->processable->installed->resolve_path(
            $file->dirname . 'doxygen.css'
        )
    ) {

        # embedded libraries
        foreach my $type (@FILE_PACKAGE_MAPPING) {

            my $typere =  $type->{'ext_regexp'};

            if($file->name =~ m/$typere/) {
                my $mapping = $type->{'mapping'};
                my $typetag = $type->{'tag'};

              LIBRARY:
                foreach my $library ($mapping->all) {

                    my $library_data = $mapping->value($library);
                    my $mainre = $library_data->{'pkg_re'};
                    my $mainpkg = $library_data->{'pkg'};
                    my $filere = $library_data->{'match'};
                    my $reinside = $library_data->{'contents_re'};

                    next LIBRARY
                      unless $file->name =~ m,$filere,;

                    next LIBRARY
                      if $self->processable->name =~ m,$mainre,;

                    if(defined $reinside) {
                        my $foundre = 0;
                        open(my $fd, '<:raw', $file->unpacked_path);
                        my $sfd = Lintian::SlidingWindow->new($fd);

                      READWINDOW:
                        while (my $block = $sfd->readwindow) {
                            if ($block =~ m{$reinside}) {
                                $foundre = 1;
                                last READWINDOW;
                            }
                        }

                        close($fd);

                        next LIBRARY
                          unless $foundre;
                    }

                    $self->tag($typetag, $file->name, 'please use', $mainpkg);
                }
            }
        }
    }

    # embedded Feedparser library
    if (    $file->name =~ m,/feedparser\.py$,
        and $self->processable->source ne 'feedparser'){

        open(my $fd, '<', $file->unpacked_path);
        while (<$fd>) {

            if (m,Universal feed parser,) {
                $self->tag('embedded-feedparser-library', $file->name);

                last;
            }
        }
        close($fd);
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
