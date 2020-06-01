# apache2 -- lintian check script -*- perl -*-
#
# Copyright © 2012 Arno Töll
# Copyright © 2017-2018 Chris Lamb <lamby@debian.org>
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

package Lintian::apache2;

use v5.20;
use warnings;
use utf8;
use autodie;

use File::Basename;

use Lintian::Relation qw(:constants);

use Moo;
use namespace::clean;

with 'Lintian::Check';

# whether the package appears to be an Apache2 module/web application
has seen_apache2_special_file => (is => 'rwp', default => 0);

sub files {
    my ($self, $file) = @_;

    # Do nothing if the package in question appears to be related to
    # the web server itself
    return
      if $self->package =~ m/^apache2(:?\.2)?(?:-\w+)?$/;

    # File is probably not relevant to us, ignore it
    return
      if $file->is_dir;

    return
      if $file !~ m#^(?:usr/lib/apache2/modules/|etc/apache2/)#;

    # Package installs an unrecognized file - check this for all files
    if (    $file !~ m#\.conf$#
        and $file =~ m#^etc/apache2/(conf|site|mods)-available/(.*)$#){
        my $temp_type = $1;
        my $temp_file = $2;

        # ... except modules which are allowed to ship .load files
        $self->tag('apache2-configuration-files-need-conf-suffix', $file)
          unless $temp_type eq 'mods' and $temp_file =~ m#\.load#;
    }

    # Package appears to be a binary module
    if ($file =~ m#^usr/lib/apache2/modules/(.*)\.so#) {
        $self->check_module_package($1);
        $self->_set_seen_apache2_special_file(1);
    }

    # Package appears to be a web application
    elsif ($file =~ m#^etc/apache2/(conf|site)-available/(.*)$#) {
        $self->check_web_application_package($file, $1, $2);
        $self->_set_seen_apache2_special_file(1);
    }

    # Package appears to be a legacy web application
    elsif ($file =~ m#^etc/apache2/conf\.d/(.*)$#) {
        $self->tag('apache2-reverse-dependency-uses-obsolete-directory',$file);
        $self->check_web_application_package($file,'conf', $1);
        $self->_set_seen_apache2_special_file(1);
    }

    # Package does scary things
    elsif ($file =~ m#^etc/apache2/(?:conf|sites|mods)-enabled/.*$#) {

        $self->tag(
            'apache2-reverse-dependency-ships-file-in-not-allowed-directory',
            $file);

        $self->_set_seen_apache2_special_file(1);
    }

    return;
}

sub installable {
    my ($self) = @_;

    # Do nothing if the package in question appears to be related to
    # the web server itself
    return
      if $self->package =~ m/^apache2(:?\.2)?(?:-\w+)?$/;

    if ($self->seen_apache2_special_file) {
        $self->check_maintainer_scripts;
    }
    return;
}

sub check_web_application_package {
    my ($self, $file, $pkgtype, $webapp) = @_;

    my $pkg = $self->package;
    my $processable = $self->processable;

    $self->tag('non-standard-apache2-configuration-name',
        $webapp, '!=', "$pkg.conf")
      if $webapp ne "$pkg.conf"
      or $webapp =~ m/^local-./;

    my $rel = Lintian::Relation->and(
        $processable->relation('strong'),
        $processable->relation('recommends'));

    # A web application must not depend on apache2-whatever
    my $visit = sub {
        if (m/^apache2(?:\.2)?-(?:common|data|bin)$/) {
            $self->tag('web-application-depends-on-apache2-data-package', $_);
            return 1;
        }
        return 0;
    };
    $rel->visit($visit, VISIT_STOP_FIRST_MATCH);

    # ... nor on apache2 only. Moreover, it should be in the form
    # apache2 | httpd but don't worry about versions, virtual package
    # don't support that
    if ($rel->implies('apache2')) {
        $self->tag(
            'web-application-should-not-depend-unconditionally-on-apache2');
    }

    $self->inspect_conf_file($pkgtype, $file);
    return;
}

sub check_module_package {
    my ($self, $module) = @_;

    my $pkg = $self->package;
    my $processable = $self->processable;

    # We want packages to be follow our naming scheme. Modules should be named
    # libapache2-mod-<foo> if it ships a mod_foo.so
    # NB: Some modules have uppercase letters in them (e.g. Ruwsgi), but
    # obviously the package should be in all lowercase.
    my $expected_name = 'libapache2-' . lc($module);

    my $rel;

    $expected_name =~ tr/_/-/;
    if ($expected_name ne $pkg) {
        $self->tag('non-standard-apache2-module-package-name',
            $pkg, '!=',$expected_name);
    }

    $rel = Lintian::Relation->and(
        $processable->relation('strong'),
        $processable->relation('recommends'));
    if (!$rel->matches(qr/^apache2-api-\d+$/)) {
        $self->tag('apache2-module-does-not-depend-on-apache2-api');
    }

    # The module is called mod_foo.so, thus the load file is expected to be
    # named foo.load
    my $load_file = $module;
    my $conf_file = $module;
    $load_file =~ s#^mod.(.*)$#etc/apache2/mods-available/$1.load#;
    $conf_file =~ s#^mod.(.*)$#etc/apache2/mods-available/$1.conf#;

    if (my $f = $processable->installed->lookup($load_file)) {
        $self->inspect_conf_file('mods', $f);
    } else {
        $self->tag('apache2-module-does-not-ship-load-file', $load_file);
    }

    if (my $f = $processable->installed->lookup($conf_file)) {
        $self->inspect_conf_file('mods', $f);
    }
    return;
}

sub check_maintainer_scripts {
    my ($self) = @_;

    my @control
      = grep { $_->is_control } $self->processable->control->sorted_list;
    for my $file (@control) {

        my $interpreter = $file->control->{interpreter};

        # skip anything but shell scripts
        next
          unless $interpreter =~ m/sh\b/;

        next
          unless $file->is_open_ok;

        open(my $sfd, '<', $file->unpacked_path);
        while (<$sfd>) {

            # skip comments
            next if substr($_, 0, $-[0]) =~ /#/;

            # Do not allow reverse dependencies to call "a2enmod" and friends
            # directly
            if (m/\b(a2(?:en|dis)(?:conf|site|mod))\b/) {

                $self->tag('apache2-reverse-dependency-calls-wrapper-script',
                    $file,$1);
            }

            # Do not allow reverse dependencies to call "invoke-rc.d apache2
            if (m/invoke-rc\.d\s+apache2/) {

                $self->tag('apache2-reverse-dependency-calls-invoke-rc.d',
                    $file);
            }

            # XXX: Check whether apache2-maintscript-helper is used
            # unconditionally e.g. not protected by a [ -e ], [ -x ] or so.
            # That's going to be complicated. Or not possible without grammar
            # parser.
        }

        close($sfd);
    }

    return;
}

sub inspect_conf_file {
    my ($self, $conftype, $file) = @_;

    # Don't follow unsafe links
    return if not $file->is_open_ok;
    open(my $fd, '<', $file->unpacked_path);
    my $skip = 0;
    while (<$fd>)  {
        $skip++
          if m{<\s*IfModule.*!\s*mod_authz_core}
          or m{<\s*IfVersion\s+<\s*2\.3};

        for my $directive ('Order', 'Satisfy', 'Allow', 'Deny',
            qr{</?Limit.*?>}xsm, qr{</?LimitExcept.*?>}xsm) {
            if (m{\A \s* ($directive) (?:\s+|\Z)}xsm and not $skip) {
                $self->tag('apache2-deprecated-auth-config',
                    $file, "(line $.)", $1);
            }
        }

        if (m/^#\s*(Depends|Conflicts):\s+(.*?)\s*$/) {
            my ($field, $value) = ($1, $2);
            $self->tag('apache2-unsupported-dependency', $file, $field)
              if $field eq 'Conflicts' and $conftype ne 'mods';
            my @dependencies = split(/[\n\s]+/, $value);
            foreach my $dep (@dependencies) {
                $self->tag('apache2-unparsable-dependency',
                    $file, "(line $.)", $dep)
                  if $dep =~ m/[^\w\.]/
                  or $dep =~ /^mod\_/
                  or $dep =~ m/\.(?:conf|load)/;
            }
        }

        $skip-- if m{<\s*/\s*If(Module|Version)};
    }
    close($fd);
    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
