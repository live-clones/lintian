# menu format -- lintian check script -*- perl -*-

# Copyright © 1998 by Joey Hess
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

# This script also checks desktop entries, since they share quite a bit of
# code.  At some point, it would make sense to try to refactor this so that
# shared code is in libraries.
#
# Further things that the desktop file validation should be checking:
#
#  - Encoding of the file should be UTF-8.
#  - Additional Categories should be associated with Main Categories.
#  - List entries (MimeType, Categories) should end with a semicolon.
#  - Check for GNOME/GTK/X11/etc. dependencies and require the relevant
#    Additional Category to be present.
#  - Check all the escape characters supported by Exec.
#  - Review desktop-file-validate to see what else we're missing.

package Lintian::Check::MenuFormat;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use File::Basename;
use List::SomeUtils qw(any first_value);
use Unicode::UTF8 qw(encode_utf8);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};
const my $SPACE => q{ };
const my $SLASH => q{/};
const my $COLON => q{:};

const my $MAXIMUM_SIZE_STANDARD_ICON => 32;
const my $MAXIMUM_SIZE_32X32_ICON => 32;
const my $MAXIMUM_SIZE_16X16_ICON => 16;

# This is a list of all tags that should be in every menu item.
my @req_tags = qw(needs section title command);

# This is a list of all known tags.
my @known_tags = qw(
  needs
  section
  title
  sort
  command
  longtitle
  icon
  icon16x16
  icon32x32
  description
  hotkey
  hints
);

# These 'needs' tags are always valid, no matter the context, and no other
# values are valid outside the Window Managers context (don't include wm here,
# in other words).  It's case insensitive, use lower case here.
my @needs_tag_vals = qw(x11 text vc);

sub _menu_sections {
    my ($key, $val, $cur) = @_;
    my $ret;
    $ret = $cur = {} unless defined $cur;
    # $val is empty if this is just a root section
    $cur->{$val} = 1 if $val;
    return $ret;
}

has MENU_SECTIONS => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->profile->load_data('menu-format/menu-sections',qr{/},
            \&_menu_sections);
    });

# Authoritative source of desktop keys:
# https://specifications.freedesktop.org/desktop-entry-spec/latest/
#
# This is a list of all keys that should be in every desktop entry.
my @req_desktop_keys = qw(Type Name);

# This is a list of all known keys.
has KNOWN_DESKTOP_KEYS => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->profile->load_data('menu-format/known-desktop-keys');
    });

has DEPRECATED_DESKTOP_KEYS => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->profile->load_data(
            'menu-format/deprecated-desktop-keys');
    });

# KDE uses some additional keys that should start with X-KDE but don't for
# historical reasons.
has KDE_DESKTOP_KEYS => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->profile->load_data('menu-format/kde-desktop-keys');
    });

# Known types of desktop entries.
# https://specifications.freedesktop.org/desktop-entry-spec/latest/ar01s06.html
my %known_desktop_types = map { $_ => 1 } qw(
  Application
  Link
  Directory
);

# Authoritative source of desktop categories:
# https://specifications.freedesktop.org/menu-spec/latest/apa.html

# This is a list of all Main Categories for .desktop files.  Application is
# added as an exception; it's not listed in the standard, but it's widely used
# and used as an example in the GNOME documentation.  GNUstep is added as an
# exception since it's used by GNUstep packages.
my %main_categories = map { $_ => 1 } qw(
  AudioVideo
  Audio
  Video
  Development
  Education
  Game
  Graphics
  Network
  Office
  Science
  Settings
  System
  Utility
  Application
  GNUstep
);

# This is a list of all Additional Categories for .desktop files.  Ideally we
# should be checking to be sure the associated Main Categories are present,
# but we don't have support for that yet.
has ADD_CATEGORIES => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my ($self) = @_;

        return $self->profile->load_data('menu-format/add-categories');
    });

# This is a list of Reserved Categories for .desktop files.  To use one of
# these, the desktop entry must also have an OnlyShowIn key limiting the
# environment to one that supports this category.
my %reserved_categories = map { $_ => 1 } qw(
  Screensaver
  TrayIcon
  Applet
  Shell
);

# Path in which to search for binaries referenced in menu entries.  These must
# not have leading slashes.
my @path = qw(usr/local/bin/ usr/bin/ bin/ usr/games/);

my %known_tags_hash = map { $_ => 1 } @known_tags;
my %needs_tag_vals_hash = map { $_ => 1 } @needs_tag_vals;

# -----------------------------------

sub installable {
    my ($self) = @_;

    my $index = $self->processable->installed;

    my (@menufiles, %desktop_cmds);
    for my $dirname (qw(usr/share/menu/ usr/lib/menu/)) {
        if (my $dir = $index->resolve_path($dirname)) {
            push(@menufiles, $dir->children);
        }
    }

    # Find the desktop files in the package for verification.
    my @desktop_files;
    for my $subdir (qw(applications xsessions)) {
        if (my $dir = $index->lookup("usr/share/$subdir/")) {
            for my $file ($dir->children) {
                next
                  unless $file->is_file;

                next
                  if $file->is_dir;

                next
                  unless $file->basename =~ /\.desktop$/;

                if ($file->is_executable) {
                    $self->hint('executable-desktop-file',
                        sprintf('%s %04o',$file, $file->operm));
                }

                push(@desktop_files, $file)
                  unless $file->name =~ / template /msx;
            }
        }
    }

    # Verify all the desktop files.
    for my $desktop_file (@desktop_files) {
        $self->verify_desktop_file($desktop_file, \%desktop_cmds);
    }

    # Now all the menu files.
    for my $menufile (@menufiles) {
        # Do not try to parse executables
        next if $menufile->is_executable or not $menufile->is_open_ok;

        # README is a special case
        next if $menufile->basename eq 'README' && !$menufile->is_dir;
        my $menufile_line =$EMPTY;

        open(my $fd, '<', $menufile->unpacked_path)
          or die encode_utf8('Cannot open ' . $menufile->unpacked_path);

        # line below is commented out in favour of the while loop
        # do { $_=<IN>; } while defined && (m/^\s* \#/ || m/^\s*$/);
        while (my $line = <$fd>) {
            if ($line =~ /^\s*\#/ || $line =~ /^\s*$/) {
                next;

            } else {
                $menufile_line = $line;
                last;
            }
        }

        # Check first line of file to see if it matches the new menu
        # file format.
        if ($menufile_line =~ m/^!C\s*menu-2/) {
            # we can't parse that yet
            close($fd);
            next;
        }

        # Parse entire file as a new format menu file.
        my $line=$EMPTY;
        my $lc=0;
        do {
            $lc++;

            # Ignore lines that are comments.
            if ($menufile_line =~ m/^\s*\#/) {
                next;
            }
            $line .= $menufile_line;
            # Note that I allow whitespace after the continuation character.
            # This is caught by verify_line().
            if (!($menufile_line =~ m/\\\s*?$/)) {
                $self->verify_line($menufile, $line,$lc,\%desktop_cmds);
                $line=$EMPTY;
            }
        } while ($menufile_line = <$fd>);
        $self->verify_line($menufile, $line,$lc,\%desktop_cmds);

        close($fd);
    }

    return;
}

# -----------------------------------

# Pass this a line of a menu file, it sanitizes it and
# verifies that it is correct.
sub verify_line {
    my ($self, $menufile, $line, $position,$desktop_cmds) = @_;

    my $pointer = $menufile->name . $COLON . $position;
    my %vals;

    chomp $line;

    # Replace all line continuation characters with whitespace.
    # (do not remove them completely, because update-menus doesn't)
    $line =~ s/\\\n/ /mg;

    # This is in here to fix a common mistake: whitespace after a '\'
    # character.
    if ($line =~ s/\\\s+\n/ /mg) {
        $self->hint('whitespace-after-continuation-character',$pointer);
    }

    # Ignore lines that are all whitespace or empty.
    return if $line =~ m/^\s*$/;

    # Ignore lines that are comments.
    return if $line =~ m/^\s*\#/;

    # Start by testing the package check.
    if (not $line =~ m/^\?package\((.*?)\):/) {
        $self->hint('bad-test-in-menu-item', $pointer);
        return;
    }
    my $pkg_test = $1;
    my %tested_packages = map { $_ => 1 } split(/\s*,\s*/, $pkg_test);
    my $tested_packages = scalar keys %tested_packages;
    unless (exists $tested_packages{$self->processable->name}) {
        $self->hint('pkg-not-in-package-test',"$pkg_test $pointer");
    }
    $line =~ s/^\?package\(.*?\)://;

    # Now collect all the tag=value pairs. I've heavily commented
    # the killer regexp that's responsible.
    #
    # The basic idea here is we start at the beginning of the line.
    # Each loop pulls off one tag=value pair and advances to the next
    # when we have no more matches, there should be no text left on
    # the line - if there is, it's a parse error.
    while (
        $line =~ m{
           \s*?                 # allow whitespace between pairs
           (                    # capture what follows in $1, it's our tag
            [^\"\s=]            # a non-quote, non-whitespace, character
            *                   # match as many as we can
           )
           =
           (                    # capture what follows in $2, it's our value
            (?:
             \"                 # this is a quoted string
             (?:
              \\.               # any quoted character
              |                 # or
              [^\"]             # a non-quote character
             )
             *                  # repeat as many times as possible
             \"                 # end of the quoted value string
            )
            |                   # the other possibility is a non-quoted string
            (?:
             [^\"\s]            # a non-quote, non-whitespace character
             *                  # match as many times as we can
            )
           )
           }gcx
    ) {
        my $tag = $1;
        my $value = $2;

        if (exists $vals{$tag}) {
            $self->hint('duplicate-tag-in-menu', $pointer, $1);
        }

        # If the value was quoted, remove those quotes.
        if ($value =~ m/^\"(.*)\"$/) {
            $value = $1;
        } else {
            $self->hint('unquoted-string-in-menu-item',$pointer, $1);
        }

        # If the value has escaped characters, remove the
        # escapes.
        $value =~ s/\\(.)/$1/g;

        $vals{$tag} = $value;
    }

    # This is not really a no-op. Note the use of the /c
    # switch - this makes perl keep track of the current
    # search position. Notice, we did it above in the loop,
    # too. (I have a /g here just so the /c takes affect.)
    # We use this below when we look at how far along in the
    # string we matched. So the point of this line is to allow
    # trailing whitespace on the end of a line.
    $line =~ m/\s*/gc;

    # If that loop didn't match up to end of line, we have a
    # problem..
    if (pos($line) < length($line)) {
        $self->hint('unparsable-menu-item', $pointer);
        # Give up now, before things just blow up in our face.
        return;
    }

    # Now validate the data in the menu file.

    # Test for important tags.
    for my $tag (@req_tags) {
        unless (exists($vals{$tag}) && defined($vals{$tag})) {
            $self->hint('menu-item-missing-required-tag',"$tag $pointer");
            # Just give up right away, if such an essential tag is missing,
            # chance is high the rest doesn't make sense either. And now all
            # following checks can assume those tags to be there
            return;
        }
    }

    # Make sure all tags are known.
    for my $tag (keys %vals) {
        if (!$known_tags_hash{$tag}) {
            $self->hint('menu-item-contains-unknown-tag',"$tag $pointer");
        }
    }

    # Sanitize the section tag
    my $section = $vals{'section'};
    $section =~ tr:/:/:s;       # eliminate duplicate slashes. # Hallo emacs ;;
    $section =~ s{/$}{}         # remove trailing slash
      unless $section eq $SLASH; # - except if $section is '/'

    # Be sure the command is provided by the package.
    my ($okay, $command)
      = $self->verify_cmd($pointer, $vals{'command'});

    $self->hint('menu-command-not-in-package', $pointer, $command)
      if !$okay
      && length $command
      && $tested_packages < 2
      && $section !~ m{^(?:WindowManagers/Modules|FVWM Modules|Window Maker)};

    if (length $command) {
        $command =~ s{^(?:usr/)?s?bin/}{};
        $command =~ s{^usr/games/}{};

        $self->hint('command-in-menu-file-and-desktop-file',$command, $pointer)
          if $desktop_cmds->{$command};
    }

    $self->verify_icon('icon', $vals{'icon'},$MAXIMUM_SIZE_STANDARD_ICON,
        $pointer);
    $self->verify_icon('icon32x32', $vals{'icon32x32'},
        $MAXIMUM_SIZE_32X32_ICON, $pointer);
    $self->verify_icon('icon16x16', $vals{'icon16x16'},
        $MAXIMUM_SIZE_16X16_ICON, $pointer);

    # needs is case insensitive
    my $needs = lc($vals{'needs'});

    if ($section =~ m{^(WindowManagers/Modules|FVWM Modules|Window Maker)}) {
        # WM/Modules: needs must not be the regular ones nor wm
        $self->hint('non-wm-module-in-wm-modules-menu-section',
            $needs, $pointer)
          if $needs_tag_vals_hash{$needs} || $needs eq 'wm';

    } elsif ($section =~ m{^Window ?Managers}) {
        # Other WM sections: needs must be wm
        $self->hint('non-wm-in-windowmanager-menu-section',$needs, $pointer)
          unless $needs eq 'wm';

    } else {
        # Any other section: just only the general ones
        if ($needs eq 'dwww') {
            $self->hint('menu-item-needs-dwww', $pointer);

        } elsif (!$needs_tag_vals_hash{$needs}) {
            $self->hint('menu-item-needs-tag-has-unknown-value',
                $needs, $pointer);
        }
    }

    # Check the section tag
    # Check for historical changes in the section tree.
    if ($section =~ m{^Apps/Games}) {
        $self->hint('menu-item-uses-apps-games-section', $pointer);
        $section =~ s{^Apps/}{};
    }

    if ($section =~ m{^Apps/}) {
        $self->hint('menu-item-uses-apps-section', $pointer);
        $section =~ s{^Apps/}{Applications/};
    }

    if ($section =~ m{^WindowManagers}) {
        $self->hint('menu-item-uses-windowmanagers-section', $pointer);
        $section =~ s{^WindowManagers}{Window Managers};
    }

    # Check for Evil new root sections.
    my ($rootsec, $sect) = split(m{/}, $section, 2);
    my $root_data = $self->MENU_SECTIONS->value($rootsec);

    if (!defined $root_data) {

        my $pkg = $self->processable->name;
        $self->hint('menu-item-creates-new-root-section',$rootsec, $pointer)
          unless $rootsec =~ /$pkg/i;

    } else {
        my $ok = 1;
        if ($sect) {
            # Using unknown subsection of $rootsec?
            $ok = 0
              unless exists $root_data->{$sect};

        } else {
            # Using root menu when a subsection exists?
            $ok = 0
              if %{$root_data};
        }

        $self->hint('menu-item-creates-new-section',$vals{section}, $pointer)
          unless $ok;
    }

    return;
}

sub verify_icon {
    my ($self, $tag, $name, $size, $pointer)= @_;

    return
      unless length $name;

    if ($name eq 'none') {

        $self->hint('menu-item-uses-icon-none', $pointer, $tag);
        return;
    }

    $self->hint('menu-icon-uses-relative-path', $pointer, $tag, $name)
      unless $name =~ s{^/+}{};

    if ($name !~ /\.xpm$/i) {

        $self->hint('menu-icon-not-in-xpm-format', $pointer, $tag, $name);
        return;
    }

    my @packages = (
        $self->processable,
        @{ $self->group->direct_dependencies($self->processable) });

    my @candidates;
    for my $processable (@packages) {

        push(@candidates, $processable->installed->resolve_path($name));
        push(@candidates,
            $processable->installed->resolve_path("usr/share/pixmaps/$name"));
    }

    my $iconfile = first_value { defined } @candidates;

    if (!defined $iconfile || !$iconfile->is_open_ok) {

        $self->hint('menu-icon-missing', $pointer, $tag, $name);
        return;
    }

    open(my $fd, '<', $iconfile->unpacked_path)
      or die encode_utf8('Cannot open ' . $iconfile->unpacked_path);

    my $parse = 'XPM header';

    my $line;
    do { defined($line = <$fd>) or goto PARSE_ERROR; }
      until ($line =~ /\/\*\s*XPM\s*\*\//);

    $parse = 'size line';

    do { defined($line = <$fd>) or goto PARSE_ERROR; }
      until ($line =~ /"\s*([0-9]+)\s*([0-9]+)\s*(?:[0-9]+)\s*(?:[0-9]+)\s*"/);
    my $width = $1 + 0;
    my $height = $2 + 0;

    if ($width > $size || $height > $size) {
        $self->hint('menu-icon-too-big', $pointer, $tag,
            "$name: ${width}x${height} > ${size}x${size}");
    }

    close($fd);

    return;

  PARSE_ERROR:
    close($fd);
    $self->hint('menu-icon-cannot-be-parsed', $pointer, $tag,
        "$name: looking for $parse");

    return;
}

# Syntax-checks a .desktop file.
sub verify_desktop_file {
    my ($self, $file, $desktop_cmds) = @_;

    my ($saw_first, $warned_cr, %vals, @pending);
    open(my $fd, '<', $file->unpacked_path)
      or die encode_utf8('Cannot open ' . $file->unpacked_path);

    while (my $line = <$fd>) {

        chomp $line;

        my $pointer = $file->name . $COLON . $.;

        next
          if $line =~ /^\s*\#/ || $line =~ /^\s*$/;

        if ($line =~ s/\r//) {
            $self->hint('desktop-entry-file-has-crs', $pointer)
              unless $warned_cr;
            $warned_cr = 1;
        }

        # Err on the side of caution for now.  If the first non-comment line
        # is not the required [Desktop Entry] group, ignore this file.  Also
        # ignore any keys in other groups.
        last
          if $saw_first && $line =~ /^\[(.*)\]\s*$/;

        unless ($saw_first) {
            return
              unless $line =~ /^\[(KDE )?Desktop Entry\]\s*$/;
            $saw_first = 1;
            $self->hint('desktop-contains-deprecated-key', $pointer)
              if $line =~ /^\[KDE Desktop Entry\]\s*$/;
        }

        # Tag = Value.  For most errors, just add the error to pending rather
        # than warning on it immediately since we want to not warn on tag
        # errors if we didn't know the file type.
        #
        # TODO: We do not check for properly formatted localised values for
        # keys but might be worth checking if they are properly formatted (not
        # their value)
        if ($line =~ /^(.*?)\s*=\s*(.*)$/) {
            my ($tag, $value) = ($1, $2);
            my $basetag = $tag;
            $basetag =~ s/\[([^\]]+)\]$//;
            if (exists $vals{$tag}) {
                $self->hint('duplicate-key-in-desktop', $pointer, $tag);
            } elsif ($self->DEPRECATED_DESKTOP_KEYS->recognizes($basetag)) {
                if ($basetag eq 'Encoding') {
                    push(@pending,
                        ['desktop-entry-contains-encoding-key',$pointer, $tag]
                    );
                } else {
                    push(
                        @pending,
                        [
                            'desktop-entry-contains-deprecated-key',
                            $pointer, $tag
                        ]);
                }
            } elsif (not $self->KNOWN_DESKTOP_KEYS->recognizes($basetag)
                and not $self->KDE_DESKTOP_KEYS->recognizes($basetag)
                and not $basetag =~ /^X-/) {
                push(@pending,
                    ['desktop-entry-contains-unknown-key', $pointer, $tag]);
            }
            $vals{$tag} = $value;
        }
    }
    close($fd);

    # Now validate the data in the desktop file, but only if it's a known type.
    # Warn if it's not.
    my $type = $vals{'Type'};
    return
      unless defined $type;

    unless ($known_desktop_types{$type}) {
        $self->hint('desktop-entry-unknown-type', $file, $type);
        return;
    }

    $self->hint(@{$_}) for @pending;

    # Test for important keys.
    for my $tag (@req_desktop_keys) {
        unless (defined $vals{$tag}) {
            $self->hint('desktop-entry-missing-required-key', $file, $tag);
        }
    }

    # test if missing Keywords (only if NoDisplay is not set)
    if (!defined $vals{NoDisplay}) {

        $self->hint('desktop-entry-lacks-icon-entry', $file)
          unless defined $vals{Icon};

        $self->hint('desktop-entry-lacks-keywords-entry', $file)
          if !defined $vals{Keywords} && $vals{'Type'} eq 'Application';
    }

    # Only test whether the binary is in the package if the desktop file is
    # directly under /usr/share/applications.  Too many applications use
    # desktop files for other purposes with custom paths.
    #
    # TODO:  Should check quoting and the check special field
    # codes in Exec for desktop files.
    if (   $file->name =~ m{^usr/share/applications/}
        && $vals{'Exec'}
        && $vals{'Exec'} =~ /\S/) {

        my ($okay, $command)
          = $self->verify_cmd($file->name, $vals{'Exec'});

        $self->hint('desktop-command-not-in-package', $file, $command)
          unless $okay
          || $command eq 'kcmshell';

        $command =~ s{^(?:usr/)?s?bin/}{};
        $desktop_cmds->{$command} = 1
          unless $command =~ m/^(?:su-to-root|sux?|(?:gk|kde)su)$/;
    }

    # Check the Category tag.
    my $in_reserved;
    if (defined $vals{'Categories'}) {

        my $saw_main;

        my @categories = split(/;/, $vals{'Categories'});
        for my $category (@categories) {

            next
              if $category =~ /^X-/;

            if ($reserved_categories{$category}) {
                $self->hint('desktop-entry-uses-reserved-category',
                    $category, $file)
                  unless $vals{'OnlyShowIn'};

                $saw_main = 1;
                $in_reserved = 1;

            } elsif (!$self->ADD_CATEGORIES->recognizes($category)
                && !$main_categories{$category}) {
                $self->hint('desktop-entry-invalid-category', $category,$file);

            } elsif ($main_categories{$category}) {
                $saw_main = 1;
            }
        }

        $self->hint('desktop-entry-lacks-main-category', $file)
          unless $saw_main;
    }

    # Check the OnlyShowIn tag.  If this is not an application in a reserved
    # category, warn about any desktop entry that specifies OnlyShowIn for
    # more than one environment.  In that case, the application probably
    # should be using NotShowIn instead.
    if (defined $vals{OnlyShowIn} and not $in_reserved) {
        my @envs = split(/;/, $vals{OnlyShowIn});
        if (@envs > 1) {
            $self->hint('desktop-entry-limited-to-environments', $file);
        }
    }

    # Check that the Exec tag specifies how to pass a filename if MimeType
    # tags are present.
    if ($file =~ m{^usr/share/applications/} && defined $vals{'MimeType'}) {

        $self->hint('desktop-mime-but-no-exec-code', $file)
          unless defined $vals{'Exec'}
          && $vals{'Exec'} =~ /(?:^|[^%])%[fFuU]/;
    }

    return;
}

# Verify whether a command is shipped as part of the package.  Takes the full
# path to the file being checked (for error reporting) and the binary.
# Returns a list whose first member is true if the command is present and
# false otherwise, and whose second member is the command (minus any leading
# su-to-root wrapper).  Shared between the desktop and menu code.
sub verify_cmd {
    my ($self, $pointer, $exec) = @_;

    my $index = $self->processable->installed;

    # This routine handles su wrappers.  The option parsing here is ugly and
    # dead-simple, but it's hopefully good enough for what will show up in
    # desktop files.  su-to-root and sux require -c options, kdesu optionally
    # allows one, and gksu has the command at the end of its arguments.
    my @components = split($SPACE, $exec);
    my $cmd;

    $self->hint('su-to-root-with-usr-sbin', $pointer)
      if $components[0] && $components[0] eq '/usr/sbin/su-to-root';

    if (   $components[0]
        && $components[0] =~ m{^(?:/usr/s?bin/)?(su-to-root|gksu|kdesu|sux)$}){

        my $wrapper = $1;
        shift @components;

        while (@components) {
            unless ($components[0]) {
                shift @components;
                next;
            }

            if ($components[0] eq '-c') {
                $cmd = $components[1];
                last;

            } elsif (
                $components[0] =~ /^-[Dfmupi]|^--(user|description|message)/) {
                shift @components;
                shift @components;

            } elsif ($components[0] =~ /^-/) {
                shift @components;

            } else {
                last;
            }
        }

        if (!$cmd && $wrapper =~ /^(gk|kde)su$/) {
            if (@components) {
                $cmd = $components[0];
            } else {
                $cmd = $wrapper;
                undef $wrapper;
            }
        }

        $self->hint('su-wrapper-without--c', $pointer, $wrapper)
          unless $cmd;

        $self->hint('su-wrapper-not-su-to-root', $pointer, $wrapper)
          if $wrapper
          && $wrapper !~ /su-to-root/
          && $wrapper ne $self->processable->name;

    } else {
        $cmd = $components[0];
    }

    my $cmd_file = $cmd;
    if ($cmd_file) {
        $cmd_file =~ s{^/}{};
    }

    my $okay = $cmd
      && ( $cmd =~ /^[\'\"]/
        || $index->lookup($cmd_file)
        || $cmd =~ m{^(/bin/)?sh}
        || $cmd =~ m{^(/usr/bin/)?sensible-(pager|editor|browser)}
        || any { $index->lookup($_ . $cmd) } @path);

    return ($okay, $cmd_file);
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
