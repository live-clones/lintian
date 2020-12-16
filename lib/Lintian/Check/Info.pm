# Copyright © 2012 Niels Thykier <niels@thykier.net>
# Copyright © 2020 Felix Lechner <felix.lechner@lease-up.com>
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

package Lintian::Check::Info;

use v5.20;
use warnings;
use utf8;

use Const::Fast;
use Path::Tiny;
use Unicode::UTF8 qw(encode_utf8);

use Lintian::Deb822::File;
use Lintian::Tag ();

use Moo;
use namespace::clean;

const my $EMPTY => q{};
const my $SLASH => q{/};

=head1 NAME

Lintian::Check::Info - Check script meta data

=head1 SYNOPSIS

 use Lintian::Check::Info;

=head1 DESCRIPTION

This class represents Lintian checks.

=head1 CLASS METHODS

=over 4

=item C<basedir>

=item name

=item module

=item type

=item type_table

=item tag_table

=cut

has basedir => (
    is => 'rw',
    coerce => sub { my ($string) = @_; return $string // $EMPTY;},
    default => $EMPTY
);

has name => (
    is => 'rw',
    coerce => sub { my ($string) = @_; return $string // $EMPTY;},
    default => $EMPTY
);

has path => (
    is => 'rw',
    coerce => sub { my ($string) = @_; return $string // $EMPTY;},
    default => $EMPTY
);

has module => (
    is => 'rw',
    coerce => sub { my ($string) = @_; return $string // $EMPTY;},
    default => $EMPTY
);

has type => (
    is => 'rw',
    coerce => sub { my ($string) = @_; return $string // 'ALL';},
    default => 'ALL'
);

has type_table => (
    is => 'rw',
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub { {} });

has tag_table => (
    is => 'rw',
    coerce => sub { my ($hashref) = @_; return ($hashref // {}); },
    default => sub { {} });

=item load

=cut

sub load {
    my ($self) = @_;

    die encode_utf8('No base directory')
      unless length $self->basedir;

    die encode_utf8('No name')
      unless length $self->name;

    my $module = $self->name;

    # replace slashes with double colons
    $module =~ s{/}{::}g;

    # replace some characters with underscores
    $module =~ s{[-.]}{_}g;

    $self->module("Lintian::Check::$module");
    $self->path($self->basedir . $SLASH . $self->name . '.pm');

    my $descpath = $self->basedir . $SLASH . $self->name . '.desc';
    return
      unless -e $descpath;

    my $deb822 = Lintian::Deb822::File->new;
    my @sections = $deb822->read_file($descpath);
    die encode_utf8("$descpath does not have exactly one paragraph")
      unless scalar @sections == 1;

    my $fields = $sections[0];

    die encode_utf8("No name field in $descpath")
      unless $fields->declares('Check-Script');

    my $name = $fields->value('Check-Script');

    die encode_utf8("Wrong name $name vs " . $self->name)
      unless $name eq $self->name;

    $self->type($fields->value('Type'));

    my %type_table;
    if ($self->type ne 'ALL') {
        for my $type (split /\s*,\s*/, $self->type) {
            $type_table{$type} = 1;
        }
    }

    $self->type_table(\%type_table);

    return;
}

=item $cs->is_check_type ($type)

Returns a truth value if this check can be applied to a $type package.

Note if $cs->type return undef, this will return a truth value for all
inputs.

=cut

sub is_check_type {
    my ($self, $type) = @_;

    # checks without specification lack an explicit type
    return 1
      unless length $self->type;

    return 1
      if $self->type  eq 'ALL';

    return $self->type_table->{$type} // 0;
}

=item $cs->add_tag ($tag)

Associates a L<tag|Lintian::Tag> as issued by this check.

=cut

sub add_tag {
    my ($self, $tag) = @_;

    $self->tag_table->{$tag->name} = $tag;

    return;
}

=item $cs->get_tag ($tagname)

Return the L<tag|Lintian::Tag> or undef (if the tag is not in
this check).

=cut

sub get_tag {
    my ($self, $tagname) = @_;

    my $global = $self->tag_table->{$tagname};

    return $global
      if defined $global;

    # try name spaced
    my $prefixed = $self->name . $SLASH . $tagname;

    my $name_spaced = $self->tag_table->{$prefixed};
    return undef
      unless defined $name_spaced;

    warn encode_utf8("Using $prefixed as name spaced while not so declared.")
      unless $name_spaced->name_spaced;

    return $name_spaced;
}

=item $cs->tags

Returns the list of tag names in the check.  The list nor its contents
should be modified.

=cut

sub tags {
    my ($self) = @_;
    return keys %{ $self->tag_table };
}

=item $cs->run_check ($proc, $group)

=cut

sub run_check {
    my ($self, $processable, $group) = @_;

    # Special-case: has no perl module
    return
      if $self->name eq 'lintian';

    require $self->path;

    if ($self->module->DOES('Lintian::Check')) {

        my $check = $self->module->new;
        $check->info($self);
        $check->processable($processable);
        $check->group($group);
        $check->profile($group->profile);

        $check->run;

        return;
    }

    my @args
      = ($processable->name,$processable->type,$processable,$processable,
        $group);

    if ($self->module->can('run')) {
        $self->module->can('run')->(@args);
        return;
    }

    $self->module->can($processable->type)->(@args)
      if $self->module->can($processable->type);

    $self->module->can('always')->(@args)
      if $self->module->can('always');

    return;
}

=back

=head1 AUTHOR

Originally written by Niels Thykier <niels@thykier.net> for Lintian.

=head1 SEE ALSO

lintian(1)

=cut

1;
__END__

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et

