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

package Lintian::languages::javascript::nodejs;

use strict;
use warnings;
use autodie;

use JSON::MaybeXS;
use List::MoreUtils qw(any);
use Path::Tiny;

use Lintian::Relation;

use Moo;
use namespace::clean;

with 'Lintian::Check';

sub source {
    my ($self) = @_;

    my $pkg = $self->package;
    my $processable = $self->processable;

    # debian/control check
    my @testsuites
      = split(m/\s*,\s*/, $processable->source_field('testsuite') // q{});
    if (any { /^autopkgtest-pkg-nodejs$/ } @testsuites) {
        # Check control file exists in sources
        my $filename = 'debian/tests/pkg-js/test';
        my $path = $processable->patched->resolve_path($filename);

        # Ensure test file contains something
        if ($path and $path->is_open_ok) {
            $self->tag('pkg-js-autopkgtest-test-is-empty', $filename)
              unless any { /^[^#]*\w/m } $path->slurp;
        } else {
            $self->tag('pkg-js-autopkgtest-test-is-missing', $filename);
        }

        # Ensure all files referenced in debian/tests/pkg-js/files exist
        $path
          = $processable->patched->resolve_path('debian/tests/pkg-js/files');

        my @files;
        @files = path($path->unpacked_path)->lines
          if defined $path;

        # trim leading and trailing whitespace
        s/^\s+|\s+$//g for @files;

        my @notfound = grep { !$self->path_exists($_) } @files;
        $self->tag('pkg-js-autopkgtest-file-does-not-exist', $_) for @notfound;
    }
    # debian/rules check
    my $droot = $processable->patched->resolve_path('debian/') or return;
    my $drules = $droot->child('rules') or return;
    return unless $drules->is_open_ok;
    open(my $rules_fd, '<', $drules->unpacked_path);
    my $command_prefix_pattern = qr/\s+[@+-]?(?:\S+=\S+\s+)*/;
    my ($seen_nodejs,$override_test,$seen_dh_dynamic);
    while (<$rules_fd>) {
        # reconstitute splitted lines
        while (s,\\$,, and defined(my $cont = <$rules_fd>)) {
            $_ .= $cont;
        }
        # skip comments
        next if /^\s*\#/;
        if (m,^(?:$command_prefix_pattern)dh\s+,) {
            $seen_dh_dynamic = 1 if m/\$[({]\w/;
            while (m/\s--with(?:=|\s+)(['"]?)(\S+)\1/go) {
                my $addon_list = $2;
                for my $addon (split(m/,/o, $addon_list)) {
                    $seen_nodejs = 1 if $addon eq 'nodejs';
                }
            }
        } elsif (/^([^:]*override_dh_[^:]*):/) {
            $override_test = 1 if $1 eq 'auto_test';
        }
    }
    if(     $seen_nodejs
        and not $override_test
        and not $seen_dh_dynamic) {
        my $filename = 'debian/tests/pkg-js/test';
        my $path = $processable->patched->resolve_path($filename);
        # Ensure test file contains something
        if ($path) {
            $self->tag('pkg-js-tools-test-is-empty', $filename)
              unless any { /^[^#]*\w/m } $path->slurp;
        } else {
            $self->tag('pkg-js-tools-test-is-missing', $filename);
        }
    }
    return;
}

sub files {
    my ($self, $file) = @_;
    return if $file->is_dir;

    return
      if $self->package =~ /-dbg$/;

    # Warn if a file is installed in old nodejs root dir
    $self->tag('nodejs-module-installed-in-usr-lib', $file->name)
      if $file->name =~ m#usr/lib/nodejs/.*#;

    # Warn if package is not installed in a subdirectory of nodejs root
    # directories
    $self->tag('node-package-install-in-nodejs-rootdir', $file->name)
      if $file->name
      =~ m#usr/(?:share|lib(?:/[^/]+)?)/nodejs/(?:package\.json|[^/]*\.js)$#;

    # Now we have to open package.json
    return unless $file->is_open_ok;

    # Return an error if a package-lock.json or a yanr.lock file is installed
    $self->tag('nodejs-lock-file', $file->name)
      if $file->name
      =~ m#usr/(?:share|lib(?:/[^/]+)?)/nodejs/([^/]+)(.*/)(package-lock\.json|yarn\.lock)$#;

    # Look only nodejs package.json files
    return
      unless $file->name
      =~ m#usr/(?:share|lib(?:/[^/]+)?)/nodejs/([^\@/]+|\@[^/]+/[^/]+)(.*/)package\.json$#;

    # First regexp arg: directory in /**/nodejs or @foo/bar when dir starts
    #                   with '@', following npm registry policy
    my $dirname = $1;
    # Second regex arg: subpath in /**/nodejs/module/ (eg: node_modules/foo)
    my $subpath = $2;

    my $declared = $self->package;
    my $processable = $self->processable;
    my $version = $processable->field('version');
    $declared .= "( = $version)" if defined $version;
    $version //= '0-1';
    my $provides
      = Lintian::Relation->and($processable->relation('provides'), $declared);

    my $content = $file->slurp;

    # Look only valid package.json files
    my $pac;
    eval {$pac = decode_json($content);};
    return if $@ or not length $pac->{name};

    # Store node module name & version (classification)
    $self->tag('nodejs-module', $pac->{name},$pac->{version} // 'undef',
        $file->name);

    # Warn if module name is not equal to nodejs directory
    if (($subpath eq '/') and ($dirname ne $pac->{name})) {
        $self->tag('nodejs-module-installed-in-bad-directory',
            $file->name, $pac->{name}, $dirname);
    } else {
        # Else verify that module is declared at least in Provides: field
        my $name = 'node-' . $pac->{name};
        # Normalize name following Debian policy
        # (replace invalid characters by "-")
        $name =~ s#[/_\@]#-#g;
        $name =~ s/\-\-+/\-/g;
        $self->tag('nodejs-module-not-declared', $name)
          if $subpath eq '/'
          and not $provides->implies($name);
    }
    return;
}

sub path_exists {
    my ($self, $expr) = @_;

    my $processable = $self->processable;

    # Split each line in path elements
    my @elem= map { s/\*/.*/g; s/^\.\*$/.*\\w.*/; $_ ? qr{^$_/?$} : () }
      split m#/#,
      $expr;
    my @dir = ('.');

    # Follow directories
  LOOP: while (my $re = shift @elem) {
        foreach my $i (0 .. $#dir) {
            my ($dir, @tmp);

            next
              unless
              defined($dir = $processable->patched->resolve_path($dir[$i]));
            next unless $dir->is_dir;
            last LOOP
              unless (
                @tmp= map { $_->basename }
                grep { $_->basename =~ $re } $dir->children
              );

            # Stop searching: at least one element found
            return 1
              unless @elem;

            # If this is the last element of path, store current elements
            my $pwd = $dir[$i];
            $dir[$i] .= '/' . shift(@tmp);

            push @dir, map { "$pwd/$_" } @tmp if @tmp;
        }
    }

    # No element found
    return 0;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
