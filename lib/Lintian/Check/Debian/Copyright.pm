# copyright -- lintian check script -*- perl -*-

# Copyright © 1998 Christian Schwarz
# Copyright © 1998 Richard Braakman
# Copyright © 2011 Jakub Wilk
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

package Lintian::Check::Debian::Copyright;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use List::SomeUtils qw(any all none uniq);
use Path::Tiny;
use Unicode::UTF8 qw(valid_utf8 decode_utf8 encode_utf8);

use Lintian::Deb822::Parser qw(parse_dpkg_control_string);
use Lintian::IPC::Run3 qw(safe_qx);
use Lintian::Spelling qw(check_spelling);

use Moo;
use namespace::clean;

with 'Lintian::Check';

const my $EMPTY => q{};

const my $APPROXIMATE_GPL_LENGTH => 12_000;
const my $APPROXIMATE_GFDL_LENGTH => 12_000;
const my $APPROXIMATE_APACHE_2_LENGTH => 10_000;

sub spelling_tag_emitter {
    my ($self, @orig_args) = @_;
    return sub {
        return $self->hint(@orig_args, @_);
    };
}

sub source {
    my ($self) = @_;

    my $debian_dir = $self->processable->patched->resolve_path('debian/');
    return
      unless defined $debian_dir;

    my @installables = $self->processable->debian_control->installables;
    my @additional = map { $_ . '.copyright' } @installables;

    my @candidates = ('copyright', @additional);
    my @files = grep { defined } map { $debian_dir->child($_) } @candidates;

    # look for <pkgname>.copyright for a single installable
    if (@files == 1) {
        my $single = $files[0];

        $self->hint('named-copyright-for-single-installable', $single->name)
          unless $single->name eq 'debian/copyright';
    }

    $self->hint('no-debian-copyright-in-source')
      unless @files;

    my @symlinks = grep { $_->is_symlink } @files;
    $self->hint('debian-copyright-is-symlink', $_->name) for @symlinks;

    return;
}

# no copyright in udebs
sub binary {
    my ($self) = @_;

    my $package = $self->processable->name;

    # looking up entry without slash first; index should not be so picky
    my $doclink
      = $self->processable->installed->lookup("usr/share/doc/$package");
    if ($doclink && $doclink->is_symlink) {

        # check if this symlink references a directory elsewhere
        if ($doclink->link =~ m{^(?:\.\.)?/}s) {
            $self->hint(
                'usr-share-doc-symlink-points-outside-of-usr-share-doc',
                $doclink->link);
            return;
        }

        # The symlink may point to a subdirectory of another
        # /usr/share/doc directory.  This is allowed if this
        # package depends on link and both packages come from the
        # same source package.
        #
        # Policy requires that packages be built from the same
        # source if they're going to do this, which by my (rra's)
        # reading means that we should have a strict version
        # dependency.  However, in practice the copyright file
        # doesn't change a lot and strict version dependencies
        # cause other problems (such as with arch: any / arch: all
        # package combinations and binNMUs).
        #
        # We therefore just require the dependency for now and
        # don't worry about the version number.
        my $link = $doclink->link;
        $link =~ s{/.*}{};

        unless ($self->depends_on($self->processable, $link)) {
            $self->hint('usr-share-doc-symlink-without-dependency', $link);

            return;
        }

        # Check if the link points to a package from the same source.
        $self->check_cross_link($link);

        return;
    }

    # now with a slash; indicates directory
    my $docdir
      = $self->processable->installed->lookup("usr/share/doc/$package/");
    unless ($docdir) {
        $self->hint('no-copyright-file');
        return;
    }

    my $found = 0;
    if ($docdir->child('copyright.gz')) {
        $self->hint('copyright-file-compressed');
        $found = 1;
    }

    my $linked = 0;

    my $file = $docdir->child('copyright');
    if ($file) {
        $found = 1;

        if ($file->is_symlink) {
            $self->hint('copyright-file-is-symlink');
            $linked = 1;
         # fall through; coll/copyright-file prevents reading through evil link
        }
    }

    unless ($found) {

        # #522827: special exception for perl for now
        $self->hint('no-copyright-file')
          unless $package eq 'perl';

        return;
    }

    my $copyrigh_path;

    my $uncompressed
      = $self->processable->installed->resolve_path(
        "usr/share/doc/$package/copyright");
    $copyrigh_path = $uncompressed->unpacked_path
      if defined $uncompressed;

    my $compressed
      = $self->processable->installed->resolve_path(
        "usr/share/doc/$package/copyright.gz");
    if (defined $compressed) {

        my $bytes = safe_qx('gunzip', '-c', $compressed->unpacked_path);
        my $contents = decode_utf8($bytes);

        my $extracted
          = path($self->processable->basedir)->child('copyright')->stringify;
        path($extracted)->spew($contents);

        $copyrigh_path = $extracted;
    }

    return
      unless length $copyrigh_path;

    my $bytes = path($copyrigh_path)->slurp;

    # another check complains about invalid encoding
    return
      unless valid_utf8($bytes);

    # check contents of copyright file
    my $contents = decode_utf8($bytes);

    $self->hint('copyright-has-crs')
      if $contents =~ /\r/;

    my $wrong_directory_detected = 0;

    my $KNOWN_COMMON_LICENSES
      =  $self->profile->load_data('copyright-file/common-licenses');

    if ($contents =~ m{ (usr/share/common-licenses/ ( [^ \t]*? ) \.gz) }xsm) {
        my ($path, $license) = ($1, $2);
        if ($KNOWN_COMMON_LICENSES->recognizes($license)) {
            $self->hint('copyright-refers-to-compressed-license', $path);
        }
    }

    # Avoid complaining about referring to a versionless license file
    # if the word "version" appears nowhere in the copyright file.
    # This won't catch all of our false positives for GPL references
    # that don't include a specific version number, but it will get
    # the obvious ones.
    if ($contents =~ m{(usr/share/common-licenses/(L?GPL|GFDL))([^-])}i) {
        my ($ref, $license, $separator) = ($1, $2, $3);
        if ($separator =~ /[\d\w]/) {
            $self->hint('copyright-refers-to-nonexistent-license-file',
                "$ref$separator");
        } elsif ($contents =~ /\b(?:any|or)\s+later(?:\s+version)?\b/i
            || $contents =~ /License: $license-[\d\.]+\+/i
            || $contents =~ /as Perl itself/i
            || $contents =~ /License-Alias:\s+Perl/
            || $contents =~ /License:\s+Perl/) {
            $self->hint('copyright-refers-to-symlink-license', $ref);
        } else {
            $self->hint('copyright-refers-to-versionless-license-file', $ref)
              if $contents =~ /\bversion\b/;
        }
    }

    # References to /usr/share/common-licenses/BSD are deprecated as of Policy
    # 3.8.5.
    if ($contents =~ m{/usr/share/common-licenses/BSD}) {
        $self->hint('copyright-refers-to-deprecated-bsd-license-file');
    }

    if ($contents =~ m{(usr/share/common-licences)}) {
        $self->hint('copyright-refers-to-incorrect-directory', $1);
        $wrong_directory_detected = 1;
    }

    if ($contents =~ m{usr/share/doc/copyright}) {
        $self->hint('copyright-refers-to-old-directory');
        $wrong_directory_detected = 1;
    }

    if ($contents =~ m{usr/doc/copyright}) {
        $self->hint('copyright-refers-to-old-directory');
        $wrong_directory_detected = 1;
    }

    # Lame check for old FSF zip code.  Try to avoid false positives from other
    # Cambridge, MA addresses.
    if ($contents =~ m/(?:Free\s*Software\s*Foundation.*02139|02111-1307)/s) {
        $self->hint('old-fsf-address-in-copyright-file');
    }

    # Whether the package is covered by the GPL, used later for the
    # libssl check.
    my $gpl;

    if (
        length $contents > $APPROXIMATE_GPL_LENGTH
        && (
            $contents =~ m{  \b \QGNU GENERAL PUBLIC LICENSE\E \s*
                    \QTERMS AND CONDITIONS FOR COPYING,\E \s*
                    \QDISTRIBUTION AND MODIFICATION\E \b }msx
            || (
                $contents =~ m{ \b \QGNU GENERAL PUBLIC LICENSE\E
                                   \s* \QVersion 3\E }msx
                && $contents =~ m{ \b \QTERMS AND CONDITIONS\E \s }msx
            ))
    ) {
        $self->hint('copyright-file-contains-full-gpl-license');
        $gpl = 1;
    }

    if (
        length $contents > $APPROXIMATE_GFDL_LENGTH
        && $contents =~ m{ \b \QGNU Free Documentation License\E
                           \s* \QVersion 1.2\E }msx
        && $contents =~ m{ \b \Q1. APPLICABILITY AND DEFINITIONS\E }msx
    ) {

        $self->hint('copyright-file-contains-full-gfdl-license');
    }

    if (   length $contents > $APPROXIMATE_APACHE_2_LENGTH
        && $contents =~ m{ \b \QApache License\E \s+ \QVersion 2.0,\E }msx
        && $contents
        =~ m{ \QTERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION\E }msx
    ) {

        $self->hint('copyright-file-contains-full-apache-2-license');
    }

    # wtf?
    if (   ($contents =~ m{common-licenses(/\S+)})
        && ($contents !~ m{/usr/share/common-licenses/})) {
        $self->hint('copyright-does-not-refer-to-common-license-file', $1);
    }

    # This check is a bit prone to false positives, since some other
    # licenses mention the GPL.  Also exclude any mention of the GPL
    # following what looks like mail header fields, since sometimes
    # e-mail discussions of licensing are included in the copyright
    # file but aren't referring to the license of the package.
    unless (
           $contents =~ m{/usr/share/common-licenses}
        || $contents =~ m/Zope Public License/
        || $contents =~ m/LICENSE AGREEMENT FOR PYTHON 1.6.1/
        || $contents =~ m/LaTeX Project Public License/
        || $contents
        =~ m/(?:^From:.*^To:|^To:.*^From:).*(?:GNU General Public License|GPL)/ms
        || $contents =~ m/AFFERO GENERAL PUBLIC LICENSE/
        || $contents =~ m/GNU Free Documentation License[,\s]*Version 1\.1/
        || $contents =~ m/CeCILL FREE SOFTWARE LICENSE AGREEMENT/ #v2.0
        || $contents =~ m/FREE SOFTWARE LICENSING AGREEMENT CeCILL/ #v1.1
        || $contents =~ m/CNRI OPEN SOURCE GPL-COMPATIBLE LICENSE AGREEMENT/
        || $contents =~ m/compatible\s+with\s+(?:the\s+)?(?:GNU\s+)?GPL/
        || $contents =~ m/(?:GNU\s+)?GPL\W+compatible/
        || $contents
        =~ m/was\s+previously\s+(?:distributed\s+)?under\s+the\s+GNU/
        || $contents
        =~ m/means\s+either\s+the\s+GNU\s+General\s+Public\s+License/
        || $wrong_directory_detected
    ) {
        if (
            check_names_texts(
                $contents,
                qr/\b(?:GFDL|gnu[-_]free[-_]documentation[-_]license)\b/i,
                qr/GNU Free Documentation License|(?-i:\bGFDL\b)/i
            )
        ) {
            $self->hint('copyright-not-using-common-license-for-gfdl');
        }elsif (
            check_names_texts(
                $contents,
qr/\b(?:LGPL|gnu[-_](?:lesser|library)[-_]general[-_]public[-_]license)\b/i,
qr/GNU (?:Lesser|Library) General Public License|(?-i:\bLGPL\b)/i
            )
        ) {
            $self->hint('copyright-not-using-common-license-for-lgpl');
        }elsif (
            check_names_texts(
                $contents,
                qr/\b(?:GPL|gnu[-_]general[-_]public[-_]license)\b/i,
                qr/GNU General Public License|(?-i:\bGPL\b)/i
            )
        ) {
            $self->hint('copyright-not-using-common-license-for-gpl');
            $gpl = 1;
        }elsif (
            check_names_texts(
                $contents,qr/\bapache[-_]2/i,
                qr/\bApache License\s*,?\s*Version 2|\b(?-i:Apache)-2/i
            )
        ) {
            $self->hint('copyright-not-using-common-license-for-apache2');
        }
    }

    if (
        check_names_texts(
            $contents,
            qr/\b(?:perl|artistic)\b/,
            sub {
                my ($text) = @_;
                $text
                  =~ /(?:under )?(?:the )?(?:same )?(?:terms )?as Perl itself\b/i
                  && $text !~ m{usr/share/common-licenses/};
            })
    ) {
        $self->hint('copyright-file-lacks-pointer-to-perl-license');
    }

    # Checks for various packaging helper boilerplate.

    $self->hint('helper-templates-in-copyright')
      if $contents =~ m{<fill in (?:http/)?ftp site>}
      || $contents =~ /<Must follow here>/
      || $contents =~ /<Put the license of the package here/
      || $contents =~ /<put author[\'\(]s\)? name and email here>/
      || $contents =~ /<Copyright \(C\) YYYY Name OfAuthor>/
      || $contents =~ /Upstream Author\(s\)/
      || $contents =~ /<years>/
      || $contents =~ /<special license>/
      || $contents
      =~ /<Put the license of the package here indented by 1 space>/
      || $contents
      =~ /<This follows the format of Description: lines\s*in control file>/
      || $contents =~ /<Including paragraphs>/
      || $contents =~ /<likewise for another author>/;

    # dh-make-perl
    $self->hint('copyright-contains-automatically-extracted-boilerplate')
      if $contents =~ /This copyright info was automatically extracted/;

    $self->hint('helper-templates-in-copyright')
      if $contents =~ /<INSERT COPYRIGHT YEAR\(S\) HERE>/;

    $self->hint('copyright-has-url-from-dh_make-boilerplate')
      if $contents =~ m{url://};

    # dh-make boilerplate
    my @dh_make_boilerplate = (
"# Please also look if there are files or directories which have a\n# different copyright/license attached and list them here.",
"# If you want to use GPL v2 or later for the /debian/* files use\n# the following clauses, or change it to suit. Delete these two lines"
    );

    $self->hint('copyright-contains-dh_make-todo-boilerplate')
      if any { $contents =~ /$_/ } @dh_make_boilerplate;

    $self->hint('copyright-with-old-dh-make-debian-copyright')
      if $contents =~ /The\s+Debian\s+packaging\s+is\s+\(C\)\s+\d+/i;

    # Other flaws in the copyright phrasing or contents.
    if ($found && !$linked) {
        $self->hint('copyright-without-copyright-notice')
          unless $contents
          =~ m{(?:Copyright|Copr\.|©)(?:.*|[\(C\):\s]+)\b\d{4}\b
               |\bpublic(?:\s+|-)domain\b}xi;
    }

    check_spelling(
        $self->profile,$contents,
        $self->group->spelling_exceptions,
        $self->spelling_tag_emitter('spelling-error-in-copyright'), 0
    );

    # Now, check for linking against libssl if the package is covered
    # by the GPL.  (This check was requested by ftp-master.)  First,
    # see if the package is under the GPL alone and try to exclude
    # packages with a mix of GPL and LGPL or Artistic licensing or
    # with an exception or exemption.
    if (($gpl || $contents =~ m{/usr/share/common-licenses/GPL})
        &&$contents
        !~ m{exception|exemption|/usr/share/common-licenses/(?!GPL)\S}){

        my @depends
          = split(/\s*,\s*/,$self->processable->fields->value('Depends'));
        my @predepends
          = split(/\s*,\s*/,$self->processable->fields->value('Pre-Depends'));

        $self->hint('possible-gpl-code-linked-with-openssl')
          if any { /^libssl[0-9.]+(?:\s|\z)/ && !/\|/ }
        (@depends, @predepends);
    }

    return;
} # </run>

# -----------------------------------

# Returns true if the package whose information is in $processable depends $package
# or if $package is essential.
sub depends_on {
    my ($self, $processable, $package) = @_;

    my $KNOWN_ESSENTIAL = $self->profile->load_data('fields/essential');

    return 1
      if $KNOWN_ESSENTIAL->recognizes($package);

    my $strong = $processable->relation('strong');
    return 1
      if $strong->satisfies($package);

    my $arch = $processable->architecture;
    return 1
      if $arch ne 'all' and $strong->satisfies("${package}:${arch}");

    return 0;
}

# Checks cross pkg links for /usr/share/doc/$pkg links
sub check_cross_link {
    my ($self, $foreign) = @_;

    my $source = $self->group->source;
    if ($source) {

        # source package is available; check its list of binaries
        return
          if any { $foreign eq $_ } $source->debian_control->installables;

        $self->hint('usr-share-doc-symlink-to-foreign-package', $foreign);

    } else {
        # The source package is not available, but the binary could
        # be present anyway;  If they are in the same group, they claim
        # to have the same source (and source version)
        return
          if any { $_->name eq $foreign }
        $self->group->get_processables('binary');

        # It was not, but since the source package was not present, we cannot
        # tell if it is foreign or not at this point.

        $self->hint(
'cannot-check-whether-usr-share-doc-symlink-points-to-foreign-package'
        );
    }

    return;
}

# Checks the name and text of every license in the file against given name and
# text check coderefs, if the file is in the new format, if the file is in the
# old format only runs the text coderef against the whole file.
sub check_names_texts {
    my ($contents, $name_check, $action) = @_;

    my $text_check;

    if ((ref($action) || $EMPTY) eq 'Regexp') {
        $text_check = sub {
            my ($textref) = @_;
            return ${$textref} =~ $action;
        };

    } else {
        $text_check = sub {
            my ($textref) = @_;
            return $action->(${$textref});
        };
    }

    my @paragraphs;

    local $@ = undef;
    eval {@paragraphs = parse_dpkg_control_string($contents);};

    # parse error: copyright not in new format, just check text
    return $text_check->(\$contents)
      if $@;

    my @licenses = grep { length } map { $_->{License} } @paragraphs;
    for my $license (@licenses) {

        my ($name, $text) = ($license =~ /^\s*([^\r\n]+)\r?\n(.*)\z/s);

        next
          unless length $text;

        next
          if $text =~ /^[\s\r\n]*\z/;

        return 1
          if $name =~ $name_check
          && $text_check->(\$text);
    }

    # did not match anything
    return 0;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
