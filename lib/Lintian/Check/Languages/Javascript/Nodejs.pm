# languages/javascript/nodejs -- lintian check script -*- perl -*-

# Copyright (C) 2019-2020, Xavier Guimard <yadd@debian.org>
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

package Lintian::Check::Languages::Javascript::Nodejs;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use JSON::MaybeXS;
use List::SomeUtils qw(any none first_value);
use Path::Tiny;
use Syntax::Keyword::Try;
use Unicode::UTF8 qw(encode_utf8);

use Lintian::Relation;

const my $SLASH => q{/};
const my $DOT => q{.};

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub source {
    my ($self) = @_;

    my $debian_control = $self->processable->debian_control;

    # debian/control check
    my @testsuites
      = split(m/\s*,\s*/,$debian_control->source_fields->value('Testsuite'));

    if (any { $_ eq 'autopkgtest-pkg-nodejs' } @testsuites) {

        my $item = $self->processable->patched->resolve_path(
            'debian/tests/pkg-js/test');
        if (defined $item) {

            $self->pointed_hint('pkg-js-autopkgtest-test-is-empty',
                $item->pointer)
              if none { /^[^#]*\w/m } $item->bytes;

        } else {
            $self->hint('pkg-js-autopkgtest-test-is-missing');
        }

        # Ensure all files referenced in debian/tests/pkg-js/files exist
        my $files
          = $self->processable->patched->resolve_path(
            'debian/tests/pkg-js/files');
        if (defined $files) {

            my @patterns = path($files->unpacked_path)->lines;

            # trim leading and trailing whitespace
            s/^\s+|\s+$//g for @patterns;

            my @notfound = grep { !$self->path_exists($_) } @patterns;

            $self->hint('pkg-js-autopkgtest-file-does-not-exist', $_)
              for @notfound;
        }
    }

    # debian/rules check
    my $droot = $self->processable->patched->resolve_path('debian/')
      or return;
    my $drules = $droot->child('rules')
      or return;

    return
      unless $drules->is_open_ok;

    open(my $rules_fd, '<', $drules->unpacked_path)
      or die encode_utf8('Cannot open ' . $drules->unpacked_path);

    my $command_prefix_pattern = qr/\s+[@+-]?(?:\S+=\S+\s+)*/;
    my ($seen_nodejs,$override_test,$seen_dh_dynamic);
    my $bdepends = $self->processable->relation('Build-Depends-All');
    $seen_nodejs = 1 if $bdepends->satisfies('dh-sequence-nodejs');

    while (my $line = <$rules_fd>) {

        # reconstitute splitted lines
        while ($line =~ s/\\$// && defined(my $cont = <$rules_fd>)) {
            $line .= $cont;
        }

        # skip comments
        next
          if $line =~ /^\s*\#/;

        if ($line =~ m{^(?:$command_prefix_pattern)dh\s+}) {
            $seen_dh_dynamic = 1
              if $line =~ /\$[({]\w/;

            while ($line =~ /\s--with(?:=|\s+)(['"]?)(\S+)\1/g) {
                my @addons = split(m{,}, $2);
                $seen_nodejs = 1
                  if any { $_ eq 'nodejs' } @addons;
            }

        } elsif ($line =~ /^([^:]*override_dh_[^:]*):/) {
            $override_test = 1
              if $1 eq 'auto_test';
        }
    }

    if(    $seen_nodejs
        && !$override_test
        && !$seen_dh_dynamic) {

        # pkg-js-tools search build test in the following order
        my @candidates = qw{debian/nodejs/test debian/tests/pkg-js/test};

        my $item = first_value { defined }
        map { $self->processable->patched->resolve_path($_) } @candidates;

        # Ensure test file contains something
        if (defined $item) {
            $self->pointed_hint('pkg-js-tools-test-is-empty', $item->pointer)
              unless any { /^[^#]*\w/m } $item->bytes;

        } else {
            $self->hint('pkg-js-tools-test-is-missing');
        }
    }

    return;
}

sub visit_installed_files {
    my ($self, $item) = @_;

    return
      if $item->is_dir;

    return
      if $self->processable->name =~ /-dbg$/;

    # Warn if a file is installed in old nodejs root dir
    $self->pointed_hint('nodejs-module-installed-in-usr-lib', $item->pointer)
      if $item->name =~ m{^usr/lib/nodejs/.*};

    # Warn if package is not installed in a subdirectory of nodejs root
    # directories
    $self->pointed_hint('node-package-install-in-nodejs-rootdir',
        $item->pointer)
      if $item->name
      =~ m{^usr/(?:share|lib(?:/[^/]+)?)/nodejs/(?:package\.json|[^/]*\.js)$};

    # Now we have to open package.json
    return
      unless $item->is_open_ok;

    # Return an error if a package-lock.json or a yanr.lock file is installed
    $self->pointed_hint('nodejs-lock-file', $item->pointer)
      if $item->name
      =~ m{^usr/(?:share|lib(?:/[^/]+)?)/nodejs/([^/]+)(.*/)(package-lock\.json|yarn\.lock)$};

    # Look only nodejs package.json files
    return
      unless $item->name
      =~ m{^usr/(?:share|lib(?:/[^/]+)?)/nodejs/([^\@/]+|\@[^/]+/[^/]+)(.*/)package\.json$};

    # First regexp arg: directory in /**/nodejs or @foo/bar when dir starts
    #                   with '@', following npm registry policy
    my $dirname = $1;
    # Second regex arg: subpath in /**/nodejs/module/ (eg: node_modules/foo)
    my $subpath = $2;

    my $declared = $self->processable->name;
    my $version = $self->processable->fields->value('Version');
    $declared .= "( = $version)"
      if length $version;
    $version ||= '0-1';

    my $provides
      = $self->processable->relation('Provides')->logical_and($declared);

    my $content = $item->bytes;

    # Look only valid package.json files
    my $pac;
    try {
        $pac = decode_json($content);
        die
          unless length $pac->{name};
    } catch {
        return;
    }

    # Store node module name & version (classification)
    $self->pointed_hint('nodejs-module', $item->pointer, $pac->{name},
        $pac->{version} // 'undef');

    # Warn if version is 0.0.0-development
    $self->pointed_hint('nodejs-missing-version-override',
        $item->pointer, $pac->{name}, $pac->{version})
      if $pac->{version} and $pac->{version} =~ /^0\.0\.0-dev/;

    # Warn if module name is not equal to nodejs directory
    if ($subpath eq $SLASH && $dirname ne $pac->{name}) {
        $self->pointed_hint('nodejs-module-installed-in-bad-directory',
            $item->pointer, $pac->{name}, $dirname);

    } else {
        # Else verify that module is declared at least in Provides: field
        my $name = 'node-' . lc($pac->{name});
        # Normalize name following Debian policy
        # (replace invalid characters by "-")
        $name =~ s{[/_\@]}{-}g;
        $name =~ s/-+/-/g;

        $self->pointed_hint('nodejs-module-not-declared', $item->pointer,$name)
          if $subpath eq $SLASH
          && !$provides->satisfies($name);
    }

    return;
}

sub path_exists {
    my ($self, $expression) = @_;

    # replace asterisks with proper regex wildcard
    $expression =~ s{ [*] }{[^/]*}gsx;

    return 1
      if any { m{^ $expression /? $}sx }
      @{$self->processable->patched->sorted_list};

    return 0;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
