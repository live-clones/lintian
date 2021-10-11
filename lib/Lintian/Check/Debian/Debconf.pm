# debian/debconf -- lintian check script -*- perl -*-

# Copyright © 2001 Colin Watson
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

package Lintian::Check::Debian::Debconf;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw(none);
use Path::Tiny;
use Unicode::UTF8 qw(encode_utf8);

use Lintian::Deb822::File;
use Lintian::Deb822::Parser qw(:constants);
use Lintian::Relation;
use Lintian::Util qw($PKGNAME_REGEX);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};
const my $SPACE => q{ };

const my $MAXIMUM_TEMPLATE_SYNOPSIS => 75;
const my $MAXIMUM_LINE_LENGTH => 80;
const my $MAXIMUM_LINES => 20;
const my $ITEM_NOT_FOUND => -1;

# From debconf-devel(7), section 'THE TEMPLATES FILE', up to date with debconf
# version 1.5.24.  Added indices for cdebconf (indicates sort order for
# choices); debconf doesn't support it, but it ignores it, which is safe
# behavior. Likewise, help is supported as of cdebconf 0.143 but is not yet
# supported by debconf.
my %template_fields
  = map { $_ => 1 } qw(Template Type Choices Indices Default Description Help);

# From debconf-devel(7), section 'THE TEMPLATES FILE', up to date with debconf
# version 1.5.24.
my %valid_types = map { $_ => 1 } qw(
  string
  password
  boolean
  select
  multiselect
  note
  error
  title
  text);

# From debconf-devel(7), section 'THE DEBCONF PROTOCOL' under 'INPUT', up to
# date with debconf version 1.5.24.
my %valid_priorities = map { $_ => 1 } qw(low medium high critical);

# All the packages that provide debconf functionality.  Anything using debconf
# needs to have dependencies that satisfy one of these.
my $ANY_DEBCONF = Lintian::Relation->new->load(
    join(
        ' | ', qw(debconf debconf-2.0 cdebconf
          cdebconf-udeb libdebconfclient0 libdebconfclient0-udeb)
    ));

sub source {
    my ($self) = @_;

    my @catalogs= (
        'templates',
        map { "$_.templates" }$self->processable->debian_control->installables
    );
    my @files = grep { defined }
      map { $self->processable->patched->resolve_path("debian/$_") } @catalogs;

    my @utf8 = grep { $_->is_valid_utf8 } @files;
    for my $file (@utf8) {

        my $contents = $file->decoded_utf8;
        my $deb822 = Lintian::Deb822::File->new;

        my @templates;
        eval {
            @templates
              = $deb822->parse_string($contents, DCTRL_DEBCONF_TEMPLATE);
        };

        if (length $@) {
            chomp $@;

            $@ =~ s/^syntax error in //;
            $self->hint('syntax-error-in-debconf-template',"$file: $@");

            next;
        }

        my @unsplit_choices
          = grep {$_->declares('Template') && $_->declares('_Choices')}
          @templates;

        $self->hint('template-uses-unsplit-choices',
            $file->name, $_->value('Template'))
          for @unsplit_choices;
    }

    return;
}

sub installable {
    my ($self) = @_;

    my $usespreinst;
    my $preinst = $self->processable->control->lookup('preinst');

    if ($preinst and $preinst->is_file and $preinst->is_open_ok) {

        open(my $fd, '<', $preinst->unpacked_path)
          or die encode_utf8('Cannot open ' . $preinst->unpacked_path);

        while (my $line = <$fd>) {
            $line =~ s/\#.*//;    # Not perfect for Perl, but should be OK

            if (   $line =~ m{/usr/share/debconf/confmodule}
                || $line =~ /(?:Debconf|Debian::DebConf)::Client::ConfModule/){
                $usespreinst=1;

                last;
            }
        }
        close($fd);
    }

    my $seenconfig;
    my $ctrl_config = $self->processable->control->lookup('config');
    if (defined $ctrl_config && $ctrl_config->is_file) {

        $self->hint('debconf-config-not-executable')
          unless $ctrl_config->is_executable;

        $seenconfig = 1;
    }

    my $seentemplates;
    my $ctrl_templates = $self->processable->control->lookup('templates');
    $seentemplates = 1 if $ctrl_templates and $ctrl_templates->is_file;

    # This still misses packages that use debconf only in the postrm.
    # Packages that ask debconf questions in the postrm should load
    # the confmodule in the postinst so that debconf can register
    # their templates.
    return
         unless $seenconfig
      or $seentemplates
      or $usespreinst;

    # parse depends info for later checks

    # Consider every package to depend on itself.
    my $selfrel;
    if ($self->processable->fields->declares('Version')) {
        my $version = $self->processable->fields->value('Version');
        $selfrel = $self->processable->name . " (= $version)";
    } else {
        $selfrel = $self->processable->name;
    }

    # Include self and provides as a package providing debconf presumably
    # satisfies its own use of debconf (if any).
    my $selfrelation
      = $self->processable->relation('Provides')->logical_and($selfrel);
    my $alldependencies
      = $self->processable->relation('strong')->logical_and($selfrelation);

    # See if the package depends on dbconfig-common.  Packages that do
    # are allowed to have a config file with no templates, since they
    # use the dbconfig-common templates.
    my $usesdbconfig = $alldependencies->satisfies('dbconfig-common');

    # Check that both debconf control area files are present.
    if ($seenconfig and not $seentemplates and not $usesdbconfig) {
        $self->hint('no-debconf-templates');
    } elsif ($seentemplates
        and not $seenconfig
        and not $usespreinst
        and $self->processable->type ne 'udeb') {
        $self->hint('no-debconf-config');
    }

    # Lots of template checks.

    my @templates;
    if ($seentemplates) {

        if ($ctrl_templates->is_valid_utf8) {
            my $contents = $ctrl_templates->decoded_utf8;
            my $deb822 = Lintian::Deb822::File->new;

            eval {
                # $seentemplates (above) will be false if $ctrl_templates is a
                # symlink or not a file, so this should be safe without
                # (re-checking) with -f/-l.
                @templates
                  = $deb822->parse_string($contents,DCTRL_DEBCONF_TEMPLATE);
            };

            if (length $@) {
                chomp $@;

                $@ =~ s/^syntax error in //;
                $self->hint(
                    'syntax-error-in-debconf-template',
                    "DEBIAN/$ctrl_templates: $@"
                );

                @templates = ();
            }
        }
    }

    my @templates_seen;
    my %potential_db_abuse;
    for my $template (@templates) {
        my $isselect = $EMPTY;

        my $name = $template->value('Template');
        if (!$template->declares('Template')) {
            $self->hint('no-template-name');
            $name = 'no-template-name';

        } else {
            push @templates_seen, $name;
            $self->hint('malformed-template-name', $name)
              unless $name =~ m{[A-Za-z0-9.+-](?:/[A-Za-z0-9.+-])};
        }

        my $type = $template->value('Type');
        if (!$template->declares('Type')) {
            $self->hint('no-template-type', $name);

        } elsif (!$valid_types{$type}) {
            # cdebconf has a special "entropy" type
            $self->hint('unknown-template-type', $type)
              unless $type eq 'entropy'
              && $alldependencies->satisfies('cdebconf');

        } elsif ($type eq 'select' || $type eq 'multiselect') {
            $isselect = 1;

        } elsif ($type eq 'boolean') {
            my $default = $template->value('Default');
            $self->hint('boolean-template-has-bogus-default', $name, $default)
              if $template->declares('Default')
              && (none { $default eq $_ } qw(true false));
        }

        my $choices = $template->value('Choices');
        if ($template->declares('Choices') && $choices !~ /^\s*$/) {

            my $nrchoices = count_choices($choices);
            for my $key ($template->names) {

                if ($key =~ /^Choices-/) {
                    my $translated = $template->value($key);
                    if (!length($translated) || $translated =~ /^\s*$/){
                        $self->hint('empty-translated-choices', $name, $key);
                    }

                    if (count_choices($translated) != $nrchoices) {
                        $self->hint('mismatch-translated-choices', $name,$key);
                    }
                }
            }

            $self->hint('select-with-boolean-choices', $name)
              if $choices =~ /^\s*(yes\s*,\s*no|no\s*,\s*yes)\s*$/i;
        }

        $self->hint('select-without-choices', $name)
          if $isselect && !$template->declares('Choices');

        my $description = $template->value('Description');
        $self->hint('no-template-description', $name)
          unless length $description
          || length $template->value('_Description');

        if ($description =~ /^\s*(.*?)\s*?\n\s*\1\s*$/){
            # Check for duplication. Should all this be folded into the
            # description checks?
            $self->hint('duplicate-long-description-in-template',$name);
        }

        my %languages;
        for my $field ($template->names) {
            # Tests on translations
            my ($mainfield, $lang) = split m/-/, $field, 2;
            if (defined $lang) {
                $languages{$lang}{$mainfield}=1;
            }
            my $stripped = $mainfield;
            $stripped =~ s/^_//;
            unless ($template_fields{$stripped}) {
                # Ignore language codes here
                $self->hint('unknown-field-in-templates',$name, $field);
            }
        }

        if (length $name && length $type) {
            $potential_db_abuse{$name} = 1
              if $type eq 'note' || $type eq 'text';
        }

        # Check the description against the best practices in the
        # Developer's Reference, but skip all templates where the
        # short description contains the string "for internal use".
        my ($short, $extended);
        if (length $description) {
            ($short, $extended) = split(/\n/, $description, 2);
            unless (defined $short) {
                $short = $description;
                $extended = $EMPTY;
            }
        } else {
            $short = $EMPTY;
            $extended = $EMPTY;
        }

        my $ttype = $type;
        unless ($short =~ /for internal use/i) {
            my $isprompt = grep { $_ eq $ttype } qw(string password);
            if ($isprompt) {
                if (
                    $short
                    && (   $short !~ m/:$/
                        || $short =~ m/^(what|who|when|where|which|how)/i)
                ) {
                    $self->hint('malformed-prompt-in-templates',$name);
                }
            }
            if ($isselect) {
                if ($short =~ /^(Please|Cho+se|Enter|Select|Specify|Give)/) {
                    $self->hint('using-imperative-form-in-templates',$name);
                }
            }
            if ($ttype eq 'boolean') {
                if ($short !~ /\?/) {
                    $self->hint('malformed-question-in-templates',$name);
                }
            }
            if (defined $extended && $extended =~ /[^\?]\?(\s+|$)/) {
                $self->hint(
                    'using-question-in-extended-description-in-templates',
                    $name);
            }
            if ($ttype eq 'note') {
                if ($short =~ /[.?;:]$/) {
                    $self->hint('malformed-title-in-templates',$name);
                }
            }
            if (length $short > $MAXIMUM_TEMPLATE_SYNOPSIS) {
                $self->hint('too-long-short-description-in-templates',$name)
                  unless $self->processable->type eq 'udeb'
                  && $ttype eq 'text';
            }
            if (defined $description) {
                if ($description
                    =~ /(\A|\s)(I|[Mm]y|[Ww]e|[Oo]ur|[Oo]urs|mine|myself|ourself|me|us)(\Z|\s)/
                ) {
                    $self->hint('using-first-person-in-templates',$name);
                }
                if (    $description =~ /[ \'\"]yes[ \'\",;.]/i
                    and $ttype eq 'boolean') {
                    $self->hint(
                        'making-assumptions-about-interfaces-in-templates',
                        $name);
                }
            }

            # Check whether the extended description is too long.
            if ($extended) {
                my $lines = 0;
                for my $string (split(/\n/, $extended)) {
                    while (length $string > $MAXIMUM_LINE_LENGTH) {
                        my $pos= rindex($string, $SPACE, $MAXIMUM_LINE_LENGTH);
                        if ($pos == $ITEM_NOT_FOUND) {
                            $pos = index($string, $SPACE);
                        }
                        if ($pos == $ITEM_NOT_FOUND) {
                            $string = $EMPTY;
                        } else {
                            $string = substr($string, $pos + 1);
                            $lines++;
                        }
                    }
                    $lines++;
                }
                if ($lines > $MAXIMUM_LINES) {
                    $self->hint('too-long-extended-description-in-templates',
                        $name);
                }
            }
        }
    }

    # Check the maintainer scripts.

    my ($config_calls_db_input, $db_purge);
    my (%templates_used, %template_aliases);
    for my $file (qw(config prerm postrm preinst postinst)) {
        my $potential_makedev = {};
        my $path = $self->processable->control->lookup($file);
        if ($path and $path->is_file and $path->is_open_ok) {
            my ($usesconfmodule, $obsoleteconfmodule, $db_input, $isdefault);

            open(my $fd, '<', $path->unpacked_path)
              or die encode_utf8('Cannot open ' . $path->unpacked_path);

            # Only check scripts.
            my $fl = <$fd>;
            unless ($fl && $fl =~ /^\#!/) {
                close($fd);
                next;
            }

            while (my $line = <$fd>) {

                # not perfect for Perl, but should be OK
                $line =~ s/#.*//;

                next
                  unless $line =~ /\S/;

                while ($line =~ s{\\$}{}) {
                    my $next = <$fd>;
                    last
                      unless $next;
                    $line .= $next;
                }

                if ($line =~ m{(?:\.|source)\s+/usr/share/debconf/confmodule}
                    || $line=~ /(?:use|require)\s+Debconf::Client::ConfModule/)
                {
                    $usesconfmodule=1;
                }

                if (
                      !$obsoleteconfmodule
                    && $line =~ m{(/usr/share/debconf/confmodule\.sh|
                   Debian::DebConf::Client::ConfModule)}x
                ) {
                    my $cmod = $1;
                    $self->hint('loads-obsolete-confmodule', "$file:$. $cmod");
                    $usesconfmodule = 1;
                    $obsoleteconfmodule = 1;
                }

                if ($file eq 'config' && $line =~ /db_input/) {
                    $config_calls_db_input = 1;
                }

                if (   $file eq 'postinst'
                    && !$db_input
                    && $line =~ /db_input/
                    && !$config_calls_db_input) {

                    # TODO: Perl?
                    $self->hint('postinst-uses-db-input')
                      unless $self->processable->type eq 'udeb';
                    $db_input=1;
                }

                if ($line =~ m{/dev/}) {
                    $potential_makedev->{$.} = 1;
                }

                if (
                    $line =~m{\A \s*(?:db_input|db_text)\s+
                     [\"\']? (\S+?) [\"\']? \s+ (\S+)\s}xsm
                ) {
                    my ($priority, $template) = ($1, $2);
                    $templates_used{$self->get_template_name($template)}= 1;

                    if ($priority !~ /^\$\S+$/) {

                        $self->hint('unknown-debconf-priority', "$file:$. $1")
                          unless ($valid_priorities{$priority});

                        $self->hint('possible-debconf-note-abuse',
                            "$file:$. $template")
                          if (
                            $potential_db_abuse{$template}
                            and (
                                not($potential_makedev->{($. - 1)}
                                    and ($priority eq 'low')))
                            and ($priority eq 'low' || $priority eq 'medium'));
                    }
                }

                if (
                    $line =~m{ \A \s* (?:db_get|db_set(?:title)?) \s+ 
                       [\"\']? (\S+?) [\"\']? (?:\s|\Z)}xsm
                ) {
                    $templates_used{$self->get_template_name($1)} = 1;
                }

                # Try to handle Perl somewhat.
                if ($line =~ /^\s*(?:.*=\s*get|set)\s*\(\s*[\"\'](\S+?)[\"\']/
                    || $line
                    =~ /\b(?:metaget|settitle)\s*\(\s*[\"\'](\S+?)[\"\']/) {
                    $templates_used{$1} = 1;
                }

                if ($line=~ /^\s*db_register\s+[\"\']?(\S+?)[\"\']?\s+(\S+)\s/)
                {
                    my ($template, $question) = ($1, $2);
                    push @{$template_aliases{$template}}, $question;
                }
                if (!$isdefault && $line =~ /db_fset.*isdefault/) {
                    # TODO: Perl?
                    $self->hint('isdefault-flag-is-deprecated', $file);
                    $isdefault = 1;
                }

                if (!$db_purge && $line =~ /db_purge/) {    # TODO: Perl?
                    $db_purge = 1;
                }
            }

            if ($self->processable->type ne 'udeb') {
                if ($file eq 'config' || ($seenconfig && $file eq 'postinst')){

                    $self->hint("$file-does-not-load-confmodule")
                      unless $usesconfmodule;
                }
            }

            if ($file eq 'postrm') {
                # If we haven't seen db_purge we emit the tag unless the
                # package is a debconf provider (in which case db_purge
                # won't be available)
                unless ($db_purge or $selfrelation->satisfies($ANY_DEBCONF)) {
                    $self->hint('postrm-does-not-purge-debconf');
                }
            }

            close($fd);

        } elsif ($file eq 'postinst') {
            $self->hint('postinst-does-not-load-confmodule')
              if $self->processable->type ne 'udeb' && $seenconfig;

        } elsif ($file eq 'postrm') {
            # Make an exception for debconf providing packages as some of
            # them (incl. "debconf" itself) cleans up in prerm and have no
            # postrm script at all.
            $self->hint('postrm-does-not-purge-debconf')
              unless $self->processable->type eq 'udeb'
              or $selfrelation->satisfies($ANY_DEBCONF);
        }
    }

    foreach my $template (@templates_seen) {
        $template =~ s/\s+\Z//;

        my $used = 0;

        if ($templates_used{$template}) {
            $used = 1;
        } else {
            foreach my $alias (@{$template_aliases{$template}}) {
                if ($templates_used{$alias}) {
                    $used = 1;
                    last;
                }
            }
        }

        $self->hint('unused-debconf-template', $template)
          unless $template =~ m{^shared/packages-(wordlist|ispell)$}
          || $template =~ m{/languages$}
          || $used
          || $self->processable->name eq 'debconf'
          || $self->processable->type eq 'udeb';
    }

    # Check that the right dependencies are in the control file.  Accept any
    # package that might provide debconf functionality.

    if ($usespreinst) {
        unless ($self->processable->relation('Pre-Depends')
            ->satisfies($ANY_DEBCONF)){
            $self->hint('missing-debconf-dependency-for-preinst')
              unless $self->processable->type eq 'udeb';
        }
    } else {
        unless ($alldependencies->satisfies($ANY_DEBCONF) or $usesdbconfig) {
            $self->hint('missing-debconf-dependency');
        }
    }

    # Now make sure that no scripts are using debconf as a registry.
    # Unfortunately this requires us to unpack to level 2 and grep all the
    # scripts in the package.
    # the following checks is ignored if the package being checked is debconf
    # itself.

    return
      if ($self->processable->name eq 'debconf')
      || ($self->processable->type eq 'udeb');

    my @scripts
      = grep { $_->is_script } @{$self->processable->installed->sorted_list};
    foreach my $file (@scripts) {

        next
          unless $file->is_open_ok;

        open(my $fd, '<', $file->unpacked_path)
          or die encode_utf8('Cannot open ' . $file->unpacked_path);

        while (my $line = <$fd>) {

            $line =~ s/#.*//;    # Not perfect for Perl, but should be OK

            if (   $line =~ m{/usr/share/debconf/confmodule}
                || $line =~ /(?:Debconf|Debian::DebConf)::Client::ConfModule/){

                $self->hint('debconf-is-not-a-registry', $file->name);
                last;
            }
        }
        close($fd);
    }

    return;
} # </run>

# -----------------------------------

# Count the number of choices.  Splitting code copied from debconf 1.5.8
# (Debconf::Question).
sub count_choices {
    my ($choices) = @_;
    my @items;
    my $item = $EMPTY;
    for my $chunk (split /(\\[, ]|,\s+)/, $choices) {
        if ($chunk =~ /^\\([, ])$/) {
            $item .= $1;
        } elsif ($chunk =~ /^,\s+$/) {
            push(@items, $item);
            $item = $EMPTY;
        } else {
            $item .= $chunk;
        }
    }
    push(@items, $item) if $item ne $EMPTY;
    return scalar(@items);
}

# Manually interpolate shell variables, eg. $DPKG_MAINTSCRIPT_PACKAGE
sub get_template_name {
    my ($self, $name) = @_;

    my $package = $self->processable->name;
    return $name =~ s/^\$DPKG_MAINTSCRIPT_PACKAGE/$package/r;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
