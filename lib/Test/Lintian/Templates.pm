# Copyright © 2018 Felix Lechner
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
# MA 02110-1301, USA

package Test::Lintian::Templates;

=head1 NAME

Test::Lintian::Templates -- Helper routines dealing with templates

=head1 SYNOPSIS

use Test::Lintian::Templates qw(fill_template);

my $data = { 'placeholder' => 'value' };
my $file = '/path/to/generated/file';

fill_template("$file.in", $file, $data);

=head1 DESCRIPTION

Routines for dealing with templates in Lintian test specifications.

=cut

use strict;
use warnings;
use autodie;
use v5.10;

use Exporter qw(import);

BEGIN {
    our @EXPORT_OK = qw(
      copy_skeleton_template_sets
      remove_surplus_templates
      fill_skeleton_templates
      fill_whitelisted_templates
      fill_all_templates
      fill_template
    );
}

use Carp;
use List::Util qw(max);
use File::Path qw(make_path);
use File::Spec::Functions qw(rel2abs abs2rel);
use File::Find::Rule;
use File::stat;
use Path::Tiny;
use Text::Template;

use Test::Lintian::ConfigFile qw(read_config);
use Test::Lintian::Helper qw(copy_dir_contents);

use constant NEWLINE => qq{\n};
use constant SPACE => q{ };
use constant DOT => q{.};
use constant COMMA => q{,};
use constant COLON => q{:};
use constant EMPTY => q{};

=head1 FUNCTIONS

=over 4

=item copy_skeleton_template_sets(INSTRUCTIONS, RUN_PATH, SUITE, TEST_SET)

Copies template sets belonging to SUITE into the test working directory
RUN_PATH according to INSTRUCTIONS. The INSTRUCTIONS are the target
directory relative to RUN_PATH followed by the name of the template set
in parentheses. Multiple such instructions must be separated by commas.

=cut

sub copy_skeleton_template_sets {
    my ($instructions, $runpath, $testset)= @_;

    # populate working directory with specified template sets
    foreach my $set (split(COMMA, $instructions)) {

        my ($relative, $name)
          =($set =~ qr/^\s*([^()\s]+)\s*\(([^()\s]+)\)\s*$/);

        croak 'No template destination specified in skeleton.'
          unless length $relative;

        croak 'No template set specified in skeleton.'
          unless length $name;

        my $templatesetpath = "$testset/templates/$name";
        croak "Cannot find template set '$name' at $templatesetpath."
          unless -d $templatesetpath;

        say "Installing template set '$name'"
          . ($relative ne DOT ? " to ./$relative." : EMPTY);

        # create directory
        my $destination = "$runpath/$relative";
        make_path($destination);

        # copy template set
        copy_dir_contents($templatesetpath, $destination)
          if -d $templatesetpath;
    }
    return;
}

=item remove_surplus_templates(SRC_DIR, TARGET_DIR)

Removes from TARGET_DIR any templates that have corresponding originals
in SRC_DIR.

=cut

sub remove_surplus_templates {
    my ($source, $destination) = @_;

    my @originals = File::Find::Rule->file->in($source);
    foreach my $original (@originals) {
        my $relative = abs2rel($original, $source);
        my $template = rel2abs("$relative.in", $destination);
        unlink($template) if -f $template;
    }
    return;
}

=item fill_skeleton_templates(INSTRUCTIONS, HASH, EPOCH, RUN_PATH, TEST_SET)

Fills the templates specified in INSTRUCTIONS using the data in HASH. Only
fills templates when the generated files are not present or are older than
either the file modification time of the template or the age of the data
as evidenced by EPOCH. The INSTRUCTIONS are the target directory relative
to RUN_PATH followed by the name of the whitelist in parentheses. Multiple
instructions must be separated by commas.

=cut

sub fill_skeleton_templates {
    my ($instructions, $testcase, $threshold, $runpath, $testset)= @_;

    foreach my $target (split(COMMA, $instructions)) {

        my ($relative, $name)
          =($target=~ qr/^\s*([^()\s]+)\s*(?:\(([^()\s]+)\))?\s*$/);

        croak 'No fill destination specified in skeleton.'
          unless length $relative;

        if (length $name) {

            # template set
            my $whitelistpath = "$testset/whitelists/$name";
            croak "Cannot find template whitelist '$name' at $whitelistpath"
              unless -f $whitelistpath;

            say EMPTY;

            say 'Generate files '
              . ($relative ne DOT ? "in ./$relative " : EMPTY)
              . "from templates using whitelist '$name'.";
            my $whitelist = read_config($whitelistpath);

            my @candidates = split(SPACE, $whitelist->{may_generate});
            my $destination = "$runpath/$relative";

            say 'Fill templates'
              . ($relative ne DOT ? " in ./$relative" : EMPTY)
              . COLON
              . SPACE
              . join(SPACE, @candidates);

            foreach my $candidate (@candidates) {
                my $generated = rel2abs($candidate, $destination);
                my $template = "$generated.in";

                # fill template if needed
                fill_template($template, $generated, $testcase, $threshold)
                  if -f $template;
            }

        }else {

            # single file
            say "Filling template: $relative";

            my $generated = rel2abs($relative, $runpath);
            my $template = "$generated.in";

            # fill template if needed
            fill_template($template, $generated, $testcase, $threshold)
              if -f $template;
        }
    }
    return;
}

=item fill_whitelisted_templates(DIR, WHITE_LIST, HASH, HASH_EPOCH)

Generates all files in array WHITE_LIST relative to DIR from their templates,
which are assumed to have the same file name but with extension '.in', using
data provided in HASH. The optional argument HASH_EPOCH can be used to
preserve files when no generation is necessary.

=cut

sub fill_whitelisted_templates {
    my ($directory, $whitelistpath, $data, $data_epoch) = @_;

    croak "No whitelist found at $whitelistpath"
      unless -f $whitelistpath;

    my $whitelist = read_config($whitelistpath);
    my @list = split(SPACE, $whitelist->{may_generate});

    foreach my $file (@list) {
        my $generated = rel2abs($file, $directory);
        my $template = "$generated.in";

        # fill template if needed
        fill_template($template, $generated, $data, $data_epoch)
          if -f $template;
    }
    return;
}

=item fill_all_templates(HASH, DIR)

Fills all templates in DIR with data from HASH.

=cut

sub fill_all_templates {
    my ($data, $data_epoch, $directory) = @_;

    my @templates = File::Find::Rule->name('*.in')->in($directory);
    foreach my $template (@templates) {
        my ($generated) = ($template =~ qr/^(.+?)\.in$/);

        # fill template if needed
        fill_template($template, $generated, $data, $data_epoch);
    }
    return;
}

=item fill_template(TEMPLATE, GENERATED, HASH, HASH_EPOCH, DELIMITERS)

Fills template TEMPLATE with data from HASH and places the result in
file GENERATED. When given HASH_EPOCH, will evaluate beforehand if a
substitution is necessary based on file modification times. The optional
parameter DELIMITERS can be used to change the standard delimiters.

=cut

sub fill_template {
    my ($template, $generated, $data, $data_epoch, $delimiters) = @_;

    my $generated_epoch
      = length $generated  && -f $generated ? stat($generated)->mtime : 0;
    my $template_epoch
      = length $template && -f $template ? stat($template)->mtime : time;
    my $threshold = max($template_epoch, $data_epoch//time);

    if ($generated_epoch <= $threshold) {

        my $filler= Text::Template->new(TYPE => 'FILE', SOURCE => $template);
        croak("Cannot read template $template: $Text::Template::ERROR")
          unless $filler;

        open(my $handle, '>', $generated)
          or croak "Could not open file $generated: $!";
        $filler->fill_in(
            OUTPUT => $handle,
            HASH => $data,
            DELIMITERS => $delimiters
          )
          or croak("Could not create file $generated from template $template");
        close($handle)
          or carp "Could not close file $generated: $!";

        # transfer file permissions from template to generated file
        my $stat = stat($template) or croak "stat $template failed: $!";
        chmod $stat->mode, $generated or croak "chmod $generated failed: $!";

        # set mtime to $threshold
        path($generated)->touch($threshold);
    }

    # delete template
    unlink($template) if -f $generated;

    return;
}

=back

=cut

1;

