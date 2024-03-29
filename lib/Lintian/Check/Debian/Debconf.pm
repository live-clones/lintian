# debian/debconf -- lintian check script -*- perl -*-

# Copyright (C) 2001 Colin Watson
# Copyright (C) 2020-21 Felix Lechner
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
# Web at https://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::Check::Debian::Debconf;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw(none);
use Path::Tiny;
use Syntax::Keyword::Try;
use Unicode::UTF8 qw(encode_utf8);

use Lintian::Deb822;
use Lintian::Deb822::Constants qw(DCTRL_DEBCONF_TEMPLATE);
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
    )
);

sub source {
    my ($self) = @_;

    my @catalogs= (
        'templates',
        map { "$_.templates" }$self->processable->debian_control->installables
    );
    my @files = grep { defined }
      map { $self->processable->patched->resolve_path("debian/$_") } @catalogs;

    my @utf8 = grep { $_->is_valid_utf8 and $_->is_file } @files;
    for my $item (@utf8) {

        my $deb822 = Lintian::Deb822->new;

        my @templates;
        try {
            @templates
              = $deb822->read_file($item->unpacked_path,
                DCTRL_DEBCONF_TEMPLATE);

        } catch {
            my $error = $@;
            chomp $error;
            $error =~ s{^syntax error in }{};

            $self->pointed_hint('syntax-error-in-debconf-template',
                $item->pointer, $error);

            next;
        }

        my @unsplit_choices
          = grep {$_->declares('Template') && $_->declares('_Choices')}
          @templates;

        $self->pointed_hint(
            'template-uses-unsplit-choices',
            $item->pointer($_->position('_Choices')),
            $_->value('Template')
        )for @unsplit_choices;
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

        $self->pointed_hint('debconf-config-not-executable',
            $ctrl_config->pointer)
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
            my $deb822 = Lintian::Deb822->new;

            try {
                # $seentemplates (above) will be false if $ctrl_templates is a
                # symlink or not a file, so this should be safe without
                # (re-checking) with -f/-l.
                @templates= $deb822->read_file($ctrl_templates->unpacked_path,
                    DCTRL_DEBCONF_TEMPLATE);

            } catch {
                my $error = $@;
                chomp $error;
                $error =~ s{^syntax error in }{};

                $self->pointed_hint('syntax-error-in-debconf-template',
                    $ctrl_templates->pointer, $error);

                @templates = ();
            }
        }
    }

    my %template_by_name;
    my %potential_db_abuse;
    for my $template (@templates) {

        my $isselect = $EMPTY;
        my $name = $template->value('Template');

        if (!$template->declares('Template')) {
            $self->pointed_hint('no-template-name',
                $ctrl_templates->pointer($template->position));
            $name = 'no-template-name';

        } else {
            $template_by_name{$name} = $template;

            $self->pointed_hint('malformed-template-name',
                $ctrl_templates->pointer($template->position('Template')),
                $name)
              unless $name =~ m{[A-Za-z0-9.+-](?:/[A-Za-z0-9.+-])};
        }

        my $type = $template->value('Type');
        if (!$template->declares('Type')) {

            $self->pointed_hint('no-template-type',
                $ctrl_templates->pointer($template->position), $name);

        } elsif (!$valid_types{$type}) {

            # cdebconf has a special "entropy" type
            $self->pointed_hint('unknown-template-type',
                $ctrl_templates->pointer($template->position('Type')), $type)
              unless $type eq 'entropy'
              && $alldependencies->satisfies('cdebconf');

        } elsif ($type eq 'select' || $type eq 'multiselect') {
            $isselect = 1;

        } elsif ($type eq 'boolean') {

            my $default = $template->value('Default');

            $self->pointed_hint(
                'boolean-template-has-bogus-default',
                $ctrl_templates->pointer($template->position('Default')),
                $name, $default
              )
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
                        $self->pointed_hint(
                            'empty-translated-choices',
                            $ctrl_templates->pointer(
                                $template->position('Choices')
                            ),
                            $name, $key
                        );
                    }

                    if (count_choices($translated) != $nrchoices) {
                        $self->pointed_hint(
                            'mismatch-translated-choices',
                            $ctrl_templates->pointer(
                                $template->position('Choices')
                            ),
                            $name,$key
                        );
                    }
                }
            }

            $self->pointed_hint('select-with-boolean-choices',
                $ctrl_templates->pointer($template->position('Choices')),$name)
              if $choices =~ /^\s*(yes\s*,\s*no|no\s*,\s*yes)\s*$/i;
        }

        $self->pointed_hint('select-without-choices',
            $ctrl_templates->pointer($template->position), $name)
          if $isselect && !$template->declares('Choices');

        my $description = $template->value('Description');

        $self->pointed_hint('no-template-description',
            $ctrl_templates->pointer($template->position), $name)
          unless length $description
          || length $template->value('_Description');

        if ($description =~ /^\s*(.*?)\s*?\n\s*\1\s*$/){

            # Check for duplication. Should all this be folded into the
            # description checks?
            $self->pointed_hint('duplicate-long-description-in-template',
                $ctrl_templates->pointer($template->position('Description')),
                $name);
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
                $self->pointed_hint('unknown-field-in-templates',
                    $ctrl_templates->pointer($template->position($field)),
                    $name, $field);
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

            my $pointer
              = $ctrl_templates->pointer($template->position('Description'));

            my $isprompt = grep { $_ eq $ttype } qw(string password);
            if ($isprompt) {
                if (
                    $short
                    && (   $short !~ m/:$/
                        || $short =~ m/^(what|who|when|where|which|how)/i)
                ) {
                    $self->pointed_hint('malformed-prompt-in-templates',
                        $pointer, $name);
                }
            }
            if ($isselect) {
                if ($short =~ /^(Please|Cho+se|Enter|Select|Specify|Give)/) {
                    $self->pointed_hint('using-imperative-form-in-templates',
                        $pointer, $name);
                }
            }
            if ($ttype eq 'boolean') {
                if ($short !~ /\?/) {
                    $self->pointed_hint('malformed-question-in-templates',
                        $pointer, $name);
                }
            }
            if (defined $extended && $extended =~ /[^\?]\?(\s+|$)/) {
                $self->pointed_hint(
                    'using-question-in-extended-description-in-templates',
                    $pointer, $name);
            }
            if ($ttype eq 'note') {
                if ($short =~ /[.?;:]$/) {
                    $self->pointed_hint('malformed-title-in-templates',
                        $pointer, $name);
                }
            }
            if (length $short > $MAXIMUM_TEMPLATE_SYNOPSIS) {
                $self->pointed_hint('too-long-short-description-in-templates',
                    $pointer, $name)
                  unless $self->processable->type eq 'udeb'
                  && $ttype eq 'text';
            }
            if (defined $description) {
                if ($description
                    =~ /(\A|\s)(I|[Mm]y|[Ww]e|[Oo]ur|[Oo]urs|mine|myself|ourself|me|us)(\Z|\s)/
                ) {
                    $self->pointed_hint('using-first-person-in-templates',
                        $pointer,$name);
                }
                if (    $description =~ /[ \'\"]yes[ \'\",;.]/i
                    and $ttype eq 'boolean') {

                    $self->pointed_hint(
                        'making-assumptions-about-interfaces-in-templates',
                        $pointer, $name);
                }
            }

            # Check whether the extended description is too long.
            if ($extended) {

                my $lines = 0;
                for my $string (split(/\n/, $extended)) {

                    while (length $string > $MAXIMUM_LINE_LENGTH) {

                        my $index
                          = rindex($string, $SPACE, $MAXIMUM_LINE_LENGTH);

                        if ($index == $ITEM_NOT_FOUND) {
                            $index = index($string, $SPACE);
                        }

                        if ($index == $ITEM_NOT_FOUND) {
                            $string = $EMPTY;

                        } else {
                            $string = substr($string, $index + 1);
                            $lines++;
                        }
                    }

                    $lines++;
                }

                if ($lines > $MAXIMUM_LINES) {
                    $self->pointed_hint(
                        'too-long-extended-description-in-templates',
                        $pointer, $name);
                }
            }
        }
    }

    # Check the maintainer scripts.

    my ($config_calls_db_input, $db_purge);
    my (%templates_used, %template_aliases);
    for my $file (qw(config prerm postrm preinst postinst)) {

        my $potential_makedev = {};

        my $item = $self->processable->control->lookup($file);

        if (defined $item && $item->is_file && $item->is_open_ok) {

            my ($usesconfmodule, $obsoleteconfmodule, $db_input, $isdefault);

            open(my $fd, '<', $item->unpacked_path)
              or die encode_utf8('Cannot open ' . $item->unpacked_path);

            # Only check scripts.
            my $fl = <$fd>;
            unless ($fl && $fl =~ /^\#!/) {
                close($fd);
                next;
            }

            my $position = 1;
            while (my $line = <$fd>) {

                # not perfect for Perl, but should be OK
                $line =~ s/#.*//;

                next
                  unless $line =~ /\S/;

                while ($line =~ s{\\$}{}) {
                    my $next = <$fd>;
                    ++$position;

                    last
                      unless $next;

                    $line .= $next;
                }

                if ($line =~ m{(?:\.|source)\s+/usr/share/debconf/confmodule}
                    || $line=~ /(?:use|require)\s+Debconf::Client::ConfModule/)
                {
                    $usesconfmodule=1;
                }

                my $pointer = $item->pointer($position);

                if (
                    !$obsoleteconfmodule
                    && $line =~ m{(/usr/share/debconf/confmodule\.sh|
                   Debian::DebConf::Client::ConfModule)}x
                ) {
                    my $module = $1;

                    $self->pointed_hint('loads-obsolete-confmodule', $pointer,
                        $module);

                    $usesconfmodule = 1;
                    $obsoleteconfmodule = 1;
                }

                if ($item->name eq 'config' && $line =~ /db_input/) {
                    $config_calls_db_input = 1;
                }

                if (   $item->name eq 'postinst'
                    && !$db_input
                    && $line =~ /db_input/
                    && !$config_calls_db_input) {

                    # TODO: Perl?
                    $self->pointed_hint('postinst-uses-db-input', $pointer)
                      unless $self->processable->type eq 'udeb';
                    $db_input=1;
                }

                if ($line =~ m{/dev/}) {
                    $potential_makedev->{$position} = 1;
                }

                if (
                    $line =~m{\A \s*(?:db_input|db_text)\s+
                     [\"\']? (\S+?) [\"\']? \s+ (\S+)\s}xsm
                ) {
                    my $priority = $1;
                    my $unmangled = $2;

                    $templates_used{$self->get_template_name($unmangled)}= 1;

                    if ($priority !~ /^\$\S+$/) {

                        $self->pointed_hint('unknown-debconf-priority',
                            $pointer, $priority)
                          unless ($valid_priorities{$priority});

                        $self->pointed_hint('possible-debconf-note-abuse',
                            $pointer, $unmangled)
                          if (
                            $potential_db_abuse{$unmangled}
                            and (
                                not($potential_makedev->{($position - 1)}
                                    and ($priority eq 'low'))
                            )
                            and ($priority eq 'low' || $priority eq 'medium')
                          );
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
                    $self->pointed_hint('isdefault-flag-is-deprecated',
                        $pointer);
                    $isdefault = 1;
                }

                if (!$db_purge && $line =~ /db_purge/) {    # TODO: Perl?
                    $db_purge = 1;
                }

            } continue {
                ++$position;
            }

            close $fd;

            if ($self->processable->type ne 'udeb') {
                if ($item->name eq 'config'
                    || ($seenconfig && $item->name eq 'postinst')){

                    $self->pointed_hint("$file-does-not-load-confmodule",
                        $item->pointer)
                      unless $usesconfmodule;
                }
            }

            if ($item->name eq 'postrm') {
                # If we haven't seen db_purge we emit the tag unless the
                # package is a debconf provider (in which case db_purge
                # won't be available)
                unless ($db_purge or $selfrelation->satisfies($ANY_DEBCONF)) {

                    $self->pointed_hint('postrm-does-not-purge-debconf',
                        $item->pointer);
                }
            }

        } elsif ($file eq 'postinst') {

            $self->hint('postinst-does-not-load-confmodule', $file)
              if $self->processable->type ne 'udeb' && $seenconfig;

        } elsif ($file eq 'postrm') {
            # Make an exception for debconf providing packages as some of
            # them (incl. "debconf" itself) cleans up in prerm and have no
            # postrm script at all.
            $self->hint('postrm-does-not-purge-debconf', $file)
              unless $self->processable->type eq 'udeb'
              or $selfrelation->satisfies($ANY_DEBCONF);
        }
    }

    for my $name (keys %template_by_name) {

        $name =~ s/\s+\Z//;

        my $used = 0;

        if ($templates_used{$name}) {
            $used = 1;
        } else {
            foreach my $alias (@{$template_aliases{$name}}) {
                if ($templates_used{$alias}) {
                    $used = 1;
                    last;
                }
            }
        }

        my $template = $template_by_name{$name};
        my $position = $template->position('Template');
        my $pointer = $ctrl_templates->pointer($position);

        $self->pointed_hint('unused-debconf-template', $pointer, $name)
          unless $name =~ m{^shared/packages-(wordlist|ispell)$}
          || $name =~ m{/languages$}
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
    for my $item (@scripts) {

        next
          unless $item->is_open_ok;

        open(my $fd, '<', $item->unpacked_path)
          or die encode_utf8('Cannot open ' . $item->unpacked_path);

        my $position = 1;
        while (my $line = <$fd>) {

            # Not perfect for Perl, but should be OK
            $line =~ s/#.*//;

            if (   $line =~ m{/usr/share/debconf/confmodule}
                || $line =~ /(?:Debconf|Debian::DebConf)::Client::ConfModule/){

                $self->pointed_hint('debconf-is-not-a-registry',
                    $item->pointer($position));
                last;
            }

        } continue {
            ++$position;
        }

        close $fd;
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
