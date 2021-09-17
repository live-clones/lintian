# languages/javascript/embedded -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz and Richard Braakman
# Copyright © 2020 Felix Lechner
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

package Lintian::Check::Languages::Javascript::Embedded;

use v5.20;
use warnings;
use utf8;

use Moo;
use namespace::clean;

with 'Lintian::Check';

my %JS_MAGIC = ('libjs-bootstrap' => 'var (Carousel|Typeahead)',);

my $JS_EXT
  = qr{(?:(?i)[-._]?(?:compiled|lite|min|pack(?:ed)?|prod|umd|yc)?\.(js|css)(?:\.gz)?)$};
my %JS_FILES = (
    'ckeditor' => qr{(?i)/ckeditor} . $JS_EXT,
    'fckeditor' => qr{(?i)/fckeditor} . $JS_EXT,
    'libjs-async' => qr{(?i)/async} . $JS_EXT,
    'libjs-bootstrap' => qr{(?i)/bootstrap(?:-[\d\.]+)?} . $JS_EXT,
    'libjs-chai'      => qr{(?i)/chai} . $JS_EXT,
    'libjs-cropper'   => qr{(?i)/cropper(?:\.uncompressed)?} . $JS_EXT,
    'libjs-dojo-\w+'  => qr{(?i)/(?:dojo|dijit)} . $JS_EXT,
    'libjs-excanvas'  => qr{(?i)/excanvas(?:-r[0-9]+)?} . $JS_EXT,
    'libjs-jac'       => qr{(?i)/jsjac} . $JS_EXT,
    'libjs-jquery'    => qr{(?i)/jquery(?:-[\d\.]+)?} . $JS_EXT,
    'libjs-jquery-cookie' => qr{(?i)/jquery\.cookie} . $JS_EXT,
    'libjs-jquery-easing' => qr{(?i)/jquery\.easing} . $JS_EXT,
    'libjs-jquery-event-drag' => qr{(?i)/jquery\.event\.drap} . $JS_EXT,
    'libjs-jquery-event-drop' => qr{(?i)/jquery\.event\.drop} . $JS_EXT,
    'libjs-jquery-fancybox'   => qr{(?i)/jquery\.fancybox} . $JS_EXT,
    'libjs-jquery-form'       => qr{(?i)/jquery\.form} . $JS_EXT,
    'libjs-jquery-galleriffic' => qr{(?i)/jquery\.galleriffic} . $JS_EXT,
    'libjs-jquery-history'     => qr{(?i)/jquery\.history} . $JS_EXT,
    'libjs-jquery-jfeed'       => qr{(?i)/jquery\.jfeed} . $JS_EXT,
    'libjs-jquery-jush'        => qr{(?i)/jquery\.jush} . $JS_EXT,
    'libjs-jquery-livequery'   => qr{(?i)/jquery\.livequery} . $JS_EXT,
    'libjs-jquery-meiomask'    => qr{(?i)/jquery\.meiomask} . $JS_EXT,
    'libjs-jquery-metadata'    => qr{(?i)/jquery\.metadata} . $JS_EXT,
    'libjs-jquery-migrate-1'   => qr{(?i)/jquery-migrate(?:-1[\d\.]*)}
      . $JS_EXT,
    'libjs-jquery-mousewheel'  => qr{(?i)/jquery\.mousewheel} . $JS_EXT,
    'libjs-jquery-opacityrollover' => qr{(?i)/jquery\.opacityrollover}
      . $JS_EXT,
    'libjs-jquery-tablesorter'     => qr{(?i)/jquery\.tablesorter} . $JS_EXT,
    'libjs-jquery-tipsy'           => qr{(?i)/jquery\.tipsy} . $JS_EXT,
    'libjs-jquery-treetable'       => qr{(?i)/jquery\.treetable} . $JS_EXT,
    'libjs-jquery-ui'              => qr{(?i)/jquery[\.-](?:-[\d\.]+)?ui}
      . $JS_EXT,
    'libjs-mocha'                  => qr{(?i)/mocha} . $JS_EXT,
    'libjs-mochikit'               => qr{(?i)/mochikit} . $JS_EXT,
    'libjs-mootools'               =>
qr{(?i)/mootools(?:(?:\.v|-)[\d\.]+)?(?:-(?:(?:core(?:-server)?)|more)(?:-(?:yc|jm|nc))?)?}
      . $JS_EXT,
    'libjs-mustache'               => qr{(?i)/mustache} . $JS_EXT,
# libjs-normalize is provided by node-normalize.css but this is an implementation detail
    'libjs-normalize'              => qr{(?i)/normalize(?:\.min)?\.css},
    'libjs-prototype'              => qr{(?i)/prototype(?:-[\d\.]+)?}. $JS_EXT,
    'libjs-raphael'                => qr{(?i)/raphael(?:[\.-]min)?} . $JS_EXT,
    'libjs-scriptaculous'          => qr{(?i)/scriptaculous} . $JS_EXT,
    'libjs-strophe'                => qr{(?i)/strophe} . $JS_EXT,
    'libjs-underscore'             => qr{(?i)/underscore} . $JS_EXT,
    'libjs-yui'                    => qr{(?i)/(?:yahoo|yui)-(?:dom-event)?}
      . $JS_EXT,
    # Disabled due to false positives.  Needs a content check adding to verify
    # that the file being checked is /the/ yahoo.js
    # 'libjs-yui'                  => qr{(?i)/yahoo\.js(\.gz)?} . $JS_EXT,
    'jsmath'                       => qr{(?i)/jsMath(?:-fallback-\w+)?}
      . $JS_EXT,
    'node-html5shiv'               => qr{(?i)html5shiv(?:-printshiv)?}
      . $JS_EXT,
    'sphinx'                       =>
      qr{(?i)/_static/(?:doctools|language_data|searchtools)} . $JS_EXT,
    'tinymce'                      => qr{(?i)/tiny_mce(?:_(?:popup|src))?}
      . $JS_EXT,
# not yet available in unstable
# 'xinha'                      => qr{(?i)/(htmlarea|Xinha(Loader|Core))} . $JS_EXT,
);

sub visit_installed_files {
    my ($self, $file) = @_;

    return
      unless $file->is_file;

    # ignore embedded jQuery libraries for Doxygen (#736360)
    my $doxygen = $self->processable->installed->resolve_path(
        $file->dirname . 'doxygen.css');
    return
      if $file->basename eq 'jquery.js'
      && defined $doxygen;

    # embedded javascript
    for my $provider (keys %JS_FILES) {

        next
          if $self->processable->name =~ /^$provider$/;

        next
          unless $file->name =~ /$JS_FILES{$provider}/;

        next
          if length $JS_MAGIC{$provider}
          && !length $file->bytes_match($JS_MAGIC{$provider});

        $self->hint('embedded-javascript-library', $file->name,
            'please use', $provider);
    }

    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
