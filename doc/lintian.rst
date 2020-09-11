=====================
Lintian User's Manual
=====================
.. sectnum::
.. contents::
   :depth: 3

.. _chapter-1:

Introduction
============

.. _section-1.1:

About Lintian
-------------

Lintian is a Debian package checker. It can be used to check binary and
source packages for compliance with the Debian policy and for other
common packaging errors.

Lintian uses an archive directory, called laboratory, in which it stores
information about the packages it examines. It can keep this information
between multiple invocations in order to avoid repeating expensive
data-collection operations. It's also possible to check the complete
Debian archive for bugs — in a timely manner.

.. _section-1.2:

The intention of Lintian
------------------------

Packaging has become complicated—not because dpkg is complicated
(indeed, dpkg-deb is very simple to use) but because of the high
requirements of our policy. If a developer releases a new package, she
has to consider hundreds of guidelines to make the package \`policy
compliant.'

All parts of our policy have been introduced by the same procedure: Some
developer has a good idea how to make packages more \`unique' with
respect to a certain aspect—then the idea is discussed and a policy
proposal is prepared. If we have a consensus about the policy change,
it's introduced in our manuals.

Therefore, our policy is *not* designed to make life harder for the
maintainers! The intention is to make Debian the best Linux distribution
out there. With this in mind, lots of policy changes are discussed on
the mailing lists each week.

But changing the policy is only a small part of the story: Just having
some statement included in the manual does not make Debian any better.
What's needed is for that policy to become \`real life,' i.e., it's
*implemented* in our packages. And this is where Lintian comes in:
Lintian checks packages and reports possible policy violations. (Of
course, not everything can be checked mechanically — but a lot of
things can and this is what Lintian is for.)

Thus, Lintian has the following goals:

-  *To give us some impression of the \`gap' between theory (written
   policy) and praxis (current state of implementation).*

   From the results of the first two Lintian checks I implemented, I see
   that there is a big need to make this gap smaller. Introducing more
   policy aspects is worthless unless they are implemented. We first
   should fix packages to comply with current policy before searching
   for new ways to make policy more detailed. (Of course, there are also
   important policy changes that need to be introduced — but this is
   not what's meant here.)

-  *To make us re-think about certain aspects of our policy.*

   For example, it could turn out that some ideas that once sounded
   great in theory are hard to implement in all our packages — in
   which case we should rework this aspect of policy.

-  *To show us where to concentrate our efforts in order to make Debian
   a higher quality distribution.*

   Most release requirements will be implemented through policy. Lintian
   reports provide an easy way to compare *all* our packages against
   policy and keep track of the fixing process by watching bug reports.
   Note, that all this can be done *automatically*.

-  *To make us avoid making the same mistakes all over again.*

   Being humans, it's natural for us to make errors. Since we all have
   the ability to learn from our mistakes, this is actually no big
   problem. Once an important bug is discovered, a Lintian check could
   be written to check for exactly this bug. This will prevent the bug
   from appearing in any future revisions of any of our packages.

.. _section-1.3:

Design issues
-------------

There are three fields of application for Lintian:

-  one person could use Lintian to check the whole Debian archive and
   reports bugs,

-  each maintainer runs Lintian over her packages before uploading them,

-  dinstall checks packages which are uploaded to master before they are
   installed in the archive.

The authors of Lintian decided to use a very modular design to achieve
the following goals:

-  flexibility: Lintian can be used to check single packages or the
   whole archive and to report and keep track of bug reports, etc.

-  completeness: Lintian will eventually include checks for (nearly)
   everything that can be checked mechanically.

-  uptodateness: Lintian will be updated whenever policy is changed.

-  performance: Lintian should make it possible to check single packages
   within seconds or check the full archive within 5 days.

The design also has a number of constrains that limits the things
Lintian can check for and what tools it can use:

-  static analysis: The code in a package may be analyzed, but it should
   *never* be executed. However, Lintian can (and does) use external
   tools to analyze files in the package.

-  deterministic replay-ability: Checks should not rely on the state of
   system caches or even the system time. These things makes it harder
   for others to reproduce (the absence of) tags.

-  same source analysis: Lintian checks packages in small isolated
   groups based on the source package. Requiring the presence of all the
   dependencies to provide the full results make it harder to run
   lintian (not to mention, it makes "deterministic replay-ability" a
   lot harder as well).

.. _section-1.4:

Disclaimer
----------

Here is a list of important notes on how to use Lintian:

1. Lintian is not finished yet and will probably never be. Please don't
   use Lintian as a reference for Debian policy. Lintian might miss a
   lot of policy violations while it might also report some violations
   by mistake. If in doubt, please check out the policy manuals.

2. The Debian policy gives the maintainers a lot of freedom. In most
   cases, the guidelines included in the manuals allow exceptions. Thus,
   if Lintian reports a policy violation on a package and you think this
   is such an exception (or if you think Lintian has a bug) you can do
   two things: If your package is a bit non-standard and weird in this
   regard, you can install an override. If you think however that the
   check is too easily or outright wrongly triggered, please file a bug
   on the lintian package.

3. Please DO NOT use Lintian to file bug reports (neither single ones
   nor mass bug reports). This is done by the authors of Lintian already
   and duplication of efforts and bug reports should be avoided! If you
   think a certain bug is \`critical' and should be reported/fixed
   immediately, please contact the maintainer of the corresponding
   package and/or the Lintian maintainers.

4. Any feedback about Lintian is welcome! Please send your comments to
   the lintian maintainers lintian-maint@debian.org.

.. _chapter-2:

Getting started
===============

.. _section-2.1:

Installing Lintian
------------------

Before you can start to check your packages with Lintian, you'll have to
install the lintian Debian package.

Alternatively you can checkout Lintian from the source repository and
use that directly. By setting LINTIAN_BASE (or using the --root option)
lintian can be run from the source directory as if it had been installed
on your system.

The only known caveat of using Lintian from the source directory is that
Lintian requires a C.UTF-8 (or en_US.UTF-8) locale to correctly process
some files. Lintian 2.5.5 supports using the C.UTF-8 locale from the
libc-bin in Debian Wheezy.

If either your version of libc-bin or Lintian are too old, you can work
around this issue by generating an en_US.UTF-8 locale. Alternatively,
installing a copy of lintian should solve this, as older versions of
Lintian generates a private locale at install time. Note, older versions
of Lintian can only use the en_US.UTF-8 locale.

.. _section-2.2:

Running lintian
---------------

After that, you can run Lintian on a changes file or any Debian binary,
udeb or source packages like this:

::

   $ lintian libc5_5.4.38-1.deb
   W: libc5: old-fsf-address-in-copyright-file
   W: libc5: shlib-without-dependency-information usr/lib/libgnumalloc.so.5.4.38
   W: libc5: shlib-without-dependency-information lib/libc.so.5.4.38
   W: libc5: shlib-without-dependency-information lib/libm.so.5.0.9
   E: libc5: shlib-with-executable-bit lib/libc.so.5.4.38 0755
   E: libc5: shlib-with-executable-bit lib/libm.so.5.0.9 0755
   E: libc5: shlib-missing-in-control-file libgnumalloc usr/lib/libgnumalloc.so.5.4.38
   $

Please note that some checks are cross-package checks and can only be
(accurately) performed if the binary packages and the source are
processed together. If Lintian is passed a changes file, it will attempt
to process all packages listed in the changes file.

Lintian supports a number of command line options, which are documented
in the manpage of lintian(1). Some of the options may appear in the
lintianrc file (without the leading dashes) in Lintian 2.5.1 (or newer).

.. _section-2.3:

Lintian Tags
------------

Lintian uses a special format for all its error and warning messages.
With that it is very easy to write other programs which run Lintian and
interpret the displayed messages.

The first character of each line indicates the type of message.
Currently, the following types are supported:

*Errors (E)*
   The displayed message indicates a policy violation or a packaging
   error. For policy violations, Lintian will cite the appropriate
   policy section when it is invoked with the ``-i`` option.

*Warnings (W)*
   The displayed message might be a policy violation or packaging error.
   A warning is usually an indication that the test is known to
   sometimes produce false positive alarms, because either the
   corresponding rule in policy has many exceptions or the test uses
   some sort of heuristic to find errors.

*Info (I)*
   The displayed message is meant to inform the maintainer about a
   certain packaging aspect. Such messages do not usually indicate
   errors, but might still be of interest to the curious. They are not
   displayed unless the ``-I`` option is set.

*Notes (N)*
   The displayed message is a debugging message which informs you about
   the current state of Lintian.

*Experimental (X)*
   The displayed message is one of the types listed above, but has been
   flagged as \`experimental' by the Lintian maintainers. This means
   that the code that generates this message is not as well tested as
   the rest of Lintian, and might still give surprising results. Feel
   free to ignore Experimental messages that do not seem to make sense,
   though of course bug reports are always welcome. They are not
   displayed unless the ``-E`` option is set.

*Overridden (O)*
   The displayed message indicates a previous *Warning* or *Error*
   message which has been *overridden* (see below). They are not
   displayed unless the ``--show-overrides`` option is set.

*Pedantic (P)*
   The displayed message indicates a message of Lintian at its most
   pickiest and include checks for particular Debian packaging styles,
   checks that are very frequently wrong, and checks that many people
   disagree with. They are not displayed unless the ``--pedantic``
   option is set.

The type indicator is followed by the name of the package and for
non-binary packages the type of the package. Then comes the *problem*
that was discovered, also known as a *tag* (for example,
``old-fsf-address-in-copyright-file``).

Depending on which tag has been reported, the line may contain
additional arguments which tell you, for example, which files are
involved.

If you do not understand what a certain tag is about, you can specify
the ``-i`` option when calling Lintian to get a detailed description of
the reported tags:

::

   $ lintian -i libc5_5.4.38-1.deb
   W: libc5: old-fsf-address-in-copyright-file
   N:
   N:   The /usr/share/doc/<pkg>/copyright file refers to the old postal
   N:   address of the Free Software Foundation (FSF). The new address is:
   N:   
   N:     Free Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
   N:     MA 02110-1301, USA.
   N:   
   N:   Visibility: warning
   N:
   [...]
   $

In some cases, the messages contain some additional text with a leading
hash character (``#``). This text should be ignored by any other
programs which interpret Lintian's output because it doesn't follow a
unique format between different messages and it's only meant as
additional information for the maintainer.

.. _section-2.4:

Overrides
---------

In some cases, the checked package does not have a bug or does not
violate policy, but Lintian still reports an error or warning. This can
have the following reasons: Lintian has a bug itself, a specific Lintian
check is not smart enough to know about a special case allowed by
policy, or the policy does allow exceptions to some rule in general.

In the first case (where Lintian has a bug) you should send a bug report
to the Debian bug tracking system and describe which package you
checked, which messages have been displayed, and why you think Lintian
has a bug. Best would be, if you would run Lintian again over your
packages using the ``-d`` (or ``--debug``) option, which will cause
Lintian to output much more information (debugging info), and include
these messages in your bug report. This will simplify the debugging
process for the authors of Lintian.

In the other two cases (where the error is actually an exception to
policy), you should probably add an override. If you're unsure though
whether it's indeed a good case for an override, you should contact the
Lintian maintainers too, including the Lintian error message and a short
note, stating why you think this is an exception. This way, the Lintian
maintainers can be sure the problem is not actually a bug in Lintian or
an error in the author's reading of policy. Please do not override bugs
in lintian, they should rather be fixed than overridden.

Once it has been decided that an override is needed, you can easily add
one by supplying an overrides file. If the override is for a binary or
udeb package, you have to place it at
``/usr/share/lintian/overrides/<package>`` inside the package. The tool
``dh_lintian`` from the Debian package debhelper may be useful for this
purpose.

If the override is for a source package, you have to place it at
``debian/source/lintian-overrides`` or
``debian/source.lintian-overrides`` (the former path is preferred). With
that, Lintian will know about this exception and not report the problem
again when checking your package. (Actually, Lintian will report the
problem again, but with type *overridden*, see above.)

Note that Lintian extracts the override file from the (u)deb and stores
it in the laboratory. The files currently installed on the system are
not used in current Lintian versions.

.. _section-2.4.1:

Format of override files
~~~~~~~~~~~~~~~~~~~~~~~~

The format of the overrides file is simple, it consists of one override
per line (and may contain empty lines and comments, starting with a
``#``, on others): ``[[<package>][ <archlist>][ <type>]: ]<lintian-tag>[
[*]<context>[*]]``. <package> is the package name;
<archlist> is an architecture list (see Architecture specific overrides
for more info); <type> is one of ``binary``, ``udeb`` and ``source``,
and <context> is all additional information provided by Lintian
except for the tag. What's inside brackets is optional and may be
omitted if you want to match it all. An example file for a binary
package would look like:

::

   /usr/share/lintian/overrides/foo, where foo is the name of your package

   # We use a non-standard dir permission to only allow the webserver to look
   # into this directory:
   foo binary: non-standard-dir-perm
   foo binary: FSSTND-dir-in-usr /usr/man/man1/foo.1.gz

An example file for a source package would look like:

::

   debian/source/lintian-overrides in your base source directory
   foo source: debian-files-list-in-source
   # Upstream distributes it like this, repacking would be overkill though, so
   # tell lintian to not complain:
   foo source: configure-generated-file-in-source config.cache

Many tags can occur more than once (e.g. if the same error is found in
more than one file). You can override a tag either completely by
specifying its name (first line in the examples) or only one occurrence
of it by specifying the additional info, too (second line in the
examples). If you add an asterisk (``*``) in the additional info, this
will match arbitrary strings similar to the shell wildcard. For example:

::

   # The "help text" must also be covered by the override
   source-is-missing apidoc/html/api_data.js *

The first wildcard support appeared in Lintian 2.0.0, which only allowed
the wildcards in the very beginning or end. Version 2.5.0~rc4 extended
this to allow wildcards any where in the additional info.

.. _section-2.4.2:

Documenting overrides
~~~~~~~~~~~~~~~~~~~~~

To assist reviewers, Lintian will extract the comments from the
overrides file and display the related comments next to the overridden
tags.

Comments directly above an override will be shown next to all tags it
overrides. If an override for the same tags appears on the very next
line, it will inherit the comment from the override above it.

::

   # This comment will be shown above all tags overridden by the following
   # two overrides, (because they apply to the same tag and there is no
   # empty line between them)
   foo source: some-tag exact match
   foo source: some-tag wildcard * match
   # This override has its own comment, and it is not shared with the
   # override below (because there is an empty line in between them).
   foo source: some-tag another exact match

   foo source: some-tag override without a comment

Empty lines can be used to disassociate a comment from an override
following it. This can also be used to make a general comment about the
overrides that will not be displayed.

::

   # This is a general comment not connected to any override, since there
   # is one (or more) empty lines after it.

   foo source: another-tag without any comments

.. _section-2.4.3:

Architecture specific overrides
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

In rare cases, Lintian tags may be architecture specific. It is possible
to mark overrides architecture specific by using the optional
architecture list.

The architecture list has the same syntax as the architecture list in
the "Build-Depends" field of a source package. This is described in
detail in the `Debian Policy Manual
§7.1 <https://www.debian.org/doc/debian-policy/#s-controlsyntax>`__.
Examples:

::

   # This is an example override that only applies to the i386
   # architecture.
   foo [i386] binary: some-tag optional-extra

   # An architecture wildcard would look like:
   foo [any-i386] binary: another-tag optional-extra

   # Negation also works
   foo [!amd64 !i386] binary: some-random-tag optional-extra

   # Negation even works for wildcards
   foo [!any-i386] binary: some-tag-not-for-i386 optional-extra

   # The package name and the package type is optional, so this
   # also works
   [linux-any]: tag-only-for-linux optional-extra.

Support for architecture specific overrides was added in Lintian 2.5.0.
Wildcard support was added in 2.5.5. Basic sanity checking was also
added in 2.5.5, where unknown architectures trigger a
``malformed-override`` tag. As does an architecture specific override
for architecture independent packages.

.. _section-2.5:

Vendor Profiles
---------------

Vendor profiles allows vendors and users to customize Lintian without
having to modify the underlying code. If a profile is not explicitly
given, Lintian will derive the best possible profile for the current
vendor from dpkg-vendor.

.. _section-2.5.1:

Rules for profile names and location
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Profile names should only consist of the lower case characters ([a-z]),
underscore (_), dash (-) and forward slashes (/). Particularly note that
dot (.) are specifically *not* allowed in a profile name.

The default profile for a vendor is called ``$VENDOR/main``. If Lintian
sees a profile name without a slash, it is taken as a short form of the
default profile for a vendor with that name.

The filename for the profile is derived from the name by simply
concatenating it with ``.profile``, Lintian will then look for a file
with that name in the following directories:

-  ``$XDG_DATA_HOME/lintian/profiles``

-  ``$HOME/.lintian/profiles``

-  ``/etc/lintian/profiles``

-  ``$LINTIAN_BASE/profiles``

Note that an implication of the handling of default vendor profiles
implies that profiles must be in subdirectories of the directories above
for Lintian to recognise them.

The directories are checked in the listed order and the first file
matching the profile will be used. This allows users to override a
system profile by putting one with the same filename in
``$XDG_DATA_HOME/lintian/profiles`` or ``$HOME/.lintian/profiles``.

.. _section-2.5.2:

Profile syntax and semantics
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Profiles are written in the same syntax as Debian control files as
described in the `Debian Policy Manual
§5.1 <https://www.debian.org/doc/debian-policy/#s-controlsyntax>`__.
Profiles allow comments as described in the Policy Manual.

.. _section-2.5.2.1:

Main profile paragraph
^^^^^^^^^^^^^^^^^^^^^^

The fields in the first paragraph are:

*Profile* (simple, mandatory)
   Name of the profile.

*Extends* (simple, optional)
   Name of the (parent) profile, which this profile extends. Lintian
   will recursively process the extended profile before continuing with
   processing this profile. In the absence of this field, the profile is
   not based on another profile.

*Load-Checks* (folded, optional)
   Comma-separated list of checks. Lintian will ensure all checks listed
   are loaded (allowing tags from them to be enabled or disabled via
   Enable-Tags or Disable-Tags).

   If a given check was already loaded before this field is processed,
   then it is silently ignored. Otherwise, the check is loaded and all
   of its tags are disabled (as if it had been listed in
   Disable-Tags-From-Check).

   This field is most likely only useful if the profile needs to enable
   a list of tags from a check in addition to any tags already enabled
   from that check (if any).

*Enable-Tags-From-Check* (folded, optional)
   Comma-separated list of checks. All tags from each check listed will
   be enabled in this profile. The check will be loaded if it wasn't
   already.

*Disable-Tags-From-Check* (folded, optional)
   Comma-separated list of checks. All tags from each check listed will
   be disabled in this profile. The check will be loaded if it wasn't
   already.

*Enable-Tags* (folded, optional)
   Comma-separated list of tags that should be enabled. It may only list
   tags from checks already loaded or listed in one of the following
   fields "Load-Checks", "Enable-Tags-From-Check" or
   "Disable-Tags-From-Check" in the current profile.

*Disable-Tags* (folded, optional)
   Comma-separated list of tags that should be disabled. It may only
   list tags from checks already loaded or listed in one of the
   following fields "Load-Checks", "Enable-Tags-From-Check" or
   "Disable-Tags-From-Check" in the current profile.

The profile is invalid and is rejected, if Enable-Tags and Disable-Tags
lists the same tag twice - even if it is in the same field. This holds
analogously for checks and the three fields Load-Checks,
Enable-Tags-From-Check and Disable-Tags-From-Check.

It is allowed to list a tag in Enable-Tags or Disable-Tags even if the
check that provides this tag is listed in the Disable-Tags-From-Check or
Enable-Tags-From-Check field. In case of conflict, Enable-Tags /
Disable-Tags shall overrule Disable-Tags-From-Check /
Enable-Tags-From-Check within the profile.

Load-Checks, Enable-Tags-From-Check and Disable-Tags-From-Check can be
used to load third-party or vendor specific checks.

It is not an error to load, enable or disable a check or tag that is
already loaded, enabled or disabled respectively (e.g. by a parent
profile).

A profile is invalid if it directly or indirectly extends itself or if
it extends an invalid profile.

By default the tags from the check "lintian" will be loaded as they
assist people in writing and maintaining their overrides file (e.g. by
emitting ``malformed-override``). However, they can be disabled by
explicitly adding the check ``lintian`` in the Disable-Tags-From-Check
field.

.. _section-2.5.2.2:

Tag alteration paragraphs
^^^^^^^^^^^^^^^^^^^^^^^^^

The fields in the secondary paragraphs are:

*Tags* (folded, mandatory)
   Comma separated list of tags affected by this paragraph.

*Overridable* (simple, optional)
   Either "Yes" or "No", which decides whether these tags can be
   overridden. Lintian will print an informal message if it sees an
   override for a tag marked as non-overridable (except if --quiet is
   passed).

*Visibility* (simple, optional)
   The value must be a valid tag visibility other than "classification".
   The visibility of the affected tags is set to this value. This cannot
   be used on any tag that is defined as a "classification" tag.

   Note that *experimental* is not a visibility.

The paragraph must contain at least one other field than the Tag field.

.. _section-2.5.2.3:

An example vendor profile
^^^^^^^^^^^^^^^^^^^^^^^^^

Below is a small example vendor profile for a fictive vendor called
"my-vendor".

::

   # The default profile for "my-vendor"
   Profile: my-vendor/main
   # It has all the checks and settings from the "debian" profile
   Extends: debian/main
   # Add checks specific to "my-vendor"
   Enable-Tags-From-Check:
     my-vendor/some-check,
     my-vendor/another-check,
   # Disable a tag
   Disable-Tags: dir-or-file-in-opt

   # Bump visibility of no-md5sums-control-file
   # and file-missing-in-md5sums and make them
   # non-overridable
   Tags: no-md5sums-control-file,
         file-missing-in-md5sums,
   Visibility: error
   Overridable: no

.. _section-2.6:

Vendor specific data files
--------------------------

Lintian uses a number of data files for various checks, ranging from
common spelling mistakes to lists of architectures. While some of these
data files are generally applicable for all vendors (or Debian
derivatives), others are not.

Starting with version 2.5.7, Lintian supports vendor specific data
files. This allows vendors to deploy their own data files tailored for
their kind of system. Lintian supports both extending an existing data
file and completely overriding it.

.. _section-2.6.1:

Load paths and order
~~~~~~~~~~~~~~~~~~~~

Lintian will search the following directories in order for vendor
specific data files:

-  ``$XDG_DATA_HOME/lintian/vendors/PROFILENAME/data``

-  ``$HOME/.lintian/vendors/PROFILENAME/data``

-  ``/etc/lintian/vendors/PROFILENAME/data``

-  ``$LINTIAN_BASE/vendors/PROFILENAME/data``

If none of the directories exists or none of them provide the data file
in question, Lintian will (recursively) retry with the parent of the
vendor (if any). If the vendor and none of its parents provide the data
file, Lintian will terminate with an error.

.. _section-2.6.2:

Basic syntax of data files
~~~~~~~~~~~~~~~~~~~~~~~~~~

Generally, data files are read line by line. Leading whitespace of every
line is removed and (now) empty lines are ignored. Lines starting with a
``#`` are comments and are also ignored by the parser. Lines are
processed in the order they are read.

If the first character of the line is a ``@``, the first word is parsed
as a special processing instruction. The rest of the line is a parameter
to that processing instruction. Please refer to `List of processing
instructions <#section-2.6.2.1>`__.

All other lines are read as actual data. If the data file is a table (or
map), the lines will parsed as key-value pairs. If the data file is a
list (or set), the full line will be considered a single value of the
list.

It is permissible to define the same key twice with a different value.
In this case, the value associated with the key is generally redefined.
There are very rare exceptions to this rule, where the data file is a
table of tables (of values). In this case, a recurring key is used to
generate the inner table.

.. _section-2.6.2.1:

List of processing instructions
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The following processing instructions are recognised:

*@delete ENTRY*
   Removes a single entry denoted by ENTRY that has already been parsed.

   It is permissible to list a non-existent entry, in which case the
   instruction has no effect. This instruction does *not* prevent the
   entry from being (re-)defined later, it only affects the current
   definition of the entry.

   For key-pair based data files, ENTRY must match the key. For single
   value data files, ENTRY must match the line to remove.

*@include-parent*
   Processes parent data file of the current data file.

   The informal semantics of this instruction is that it reads the
   "next" data file in the vendor "chain". The parsing of the parent is
   comparable to a C-style include or sourcing a shell script.

   More formally, let CP be the name of the vendor profile that defines
   the data file containing the instruction. Let the parent of CP be
   referred to as PCP.

   Lintian will search for the data file provided by PCP using the rules
   as specified in `Load paths and order <#section-2.6.1>`__. If no data
   file is found, Lintian will terminate the parsing with an error.
   Thus, this instruction can only be used by profiles that extends
   other profiles.

.. _chapter-3:

Advanced usage
==============

.. _section-3.1:

How Lintian works
-----------------

Lintian is divided into the following layers:

*frontend*
   the command line interface (currently, this layer consists of the
   ``lintian`` program.

*checks*
   a set of modules that check different aspects of packages.

*data collectors*
   a set of scripts that prepares specific information about a package
   needed by the check modules

When you check a package with Lintian, the following steps are performed
(not exactly in this order—but the details aren't important now):

1. An entry is created for the package in the *laboratory* (or just
   *lab*).

2. Some data is collected about the package. (That is done by the
   so-called *data collector* scripts.) For example, the ``file``
   program is run on each file in the package and the output is stored
   in the lab.

3. The *checks* are run over the package and report any discovered
   policy violations or other errors. These scripts don't access the
   package contents directly, but use the collected data as input.

4. Depending on the *lab mode* Lintian uses (see below), the whole lab
   directory is removed again. If the lab is not removed, parts of the
   data collected may be auto cleaned to reduce disk space.

This separation of the *check* from the *data collector scripts* makes
it possible to run Lintian several times over a package without having
to recollect all the data each time. In addition, the checker scripts do
not have to worry about packaging details since this is abstracted away
by the collector scripts.

.. _section-3.2:

The laboratory
--------------

Lintian creates a temporary lab in ``/tmp`` which is removed again after
Lintian has completed its checks, unless the ``--keep-lab`` is used.

.. _section-3.3:

Writing your own Lintian checks
-------------------------------

This section describes how to write and deploy your own Lintian checks.
Lintian will load checks from the following directories (in order):

-  ``$LINTIAN_BASE/checks``

Existing checks can be shadowed by placing a check with the same name in
a directory appearing earlier in the list. This also holds for the
checks provided by Lintian itself.

Checks in Lintian consist of a description file (.desc) and a Perl
module implementing the actual check (.pm). The names of these checks
must consist entirely of the lower case characters ([a-z]), digits
([0-9]), underscore (_), dash (-), period (.) and forward slashes (/).

The check name must be a valid Perl unique module name after the
following transformations. All periods and dashes are replaced with
underscores. All forward slashes are replaced with two colons (::).

Check names without a forward slash (e.g. "fields") and names starting
with either "lintian/" or "coll/" are reserved for the Lintian core.
Vendors are recommended to use their vendor name before the first slash
(e.g. "ubuntu/fields").

.. _section-3.3.1:

Check description file
~~~~~~~~~~~~~~~~~~~~~~

The check description file is written in the same syntax as Debian
control files as described in the `Debian Policy Manual
§5.1 <https://www.debian.org/doc/debian-policy/#s-controlsyntax>`__.
Check description files allow comments as described in the Policy
Manual.

The check description file has two paragraph types. The first is the
check description itself and must be the first paragraph. The rest of
the descriptions describe tags, one tag per paragraph.

.. _section-3.3.1.1:

Check description paragraph
^^^^^^^^^^^^^^^^^^^^^^^^^^^

The fields in the check description paragraph are:

*Check-Script* (simple, mandatory)
   Name of the check. This is used to determine the package name of the
   Perl module implementing the check.

*Type* (simple, mandatory)
   Comma separated list of package types for which this check should be
   run. Allowed values in the list are "binary" (.deb files), "changes"
   (.changes files), "source" (.dsc files) and "udeb" (.udeb files).

*Info* (multiline, optional)
   A short description of what the check is for.

*Author* (simple, optional)
   Name and email of the person, who created (or implemented etc.) the
   check.

*Abbrev* (simple, optional)
   Alternative or abbreviated name of the check. These can be used with
   certain command line options as an alternative name for the check.

.. _section-3.3.1.2:

Tag description paragraph
^^^^^^^^^^^^^^^^^^^^^^^^^

The fields in the tag description paragraph are:

*Tag* (simple, mandatory)
   Name of the tag. It must consist entirely of the lower or/and upper
   case characters ([a-zA-Z]), digits ([0-9]), underscore (_), dash (-)
   and period (.). The tag name should be at most 68 characters long.

*Severity* (simple, mandatory)
   Determines the default value for the alert level. The value must be
   one of "error", "warning", "info", "pedantic", or "classification".
   This correlates directly to the one-letter code (of non-experimental
   tags).

*Info* (multiline, mandatory)
   The tag descriptions can be found on Lintian's website
   ("https://lintian.debian.org"). The description is in the standard
   Markdown format.

   The symbols &, < and > must be escaped as &amp;, &lt; and &gt;
   (respectively). Please also escape _ as &lowbar; and * as &ast;.

   Indented lines are considered "pre-formatted" and will not be line
   wrapped. These lines are still subject to the allowed HTML tags and
   above mentioned escape sequences.

*Ref* (simple, optional)
   A comma separated list of references. It can be used to refer to
   extra documentation. It is primarily used for manual references, HTTP
   links or Debian bug references.

   If a reference contains a space, it is taken as a manual reference
   (e.g. "policy 4.14"). These references are recorded in the
   "output/manual-references" data file.

   Other references include manpages ("lintian(1)"), ftp or http(s)
   links ("https://lintian.debian.org"), file references
   ("/usr/share/doc/lintian/changelog.gz") or Debian bug numbers
   prefixed with a hash ("#651816").

   Unknown references are (silently) ignored.

*Experimental* (simple, optional)
   Whether or not the tag is considered "experimental". Recognised
   values are "no" (default) and "yes". Experimental tags always use "X"
   as their "one-letter" code.

.. _section-3.3.2:

Check Perl module file
~~~~~~~~~~~~~~~~~~~~~~

This section describes the requirements for the Perl module implementing
a given check.

The Perl package name of the check must be identical to the check name
(as defined by the "Check-Script" field in the description file) with
the following transformations:

-  All periods and dashes are replaced with underscores.

-  All forward slashes are replaced by two colons (::).

-  The resulting value is prefixed with "Lintian::".

As an example, the check name ``contrib/hallo-world`` will result in the
Perl package name ``Lintian::contrib::hallo_world``.

.. _section-3.3.2.1:

API of the "run" sub
^^^^^^^^^^^^^^^^^^^^

The Perl module must implement the sub called ``run`` in that Perl
package. This sub will be run once for each package to be checked with 5
arguments. These are (in order):

-  The package name.

-  The package type being checked in this run. This string is one of
   "binary" (.deb), "changes" (.changes), "source" (.dsc) or "udeb"
   (.udeb).

-  An instance of API Lintian::Collect. Its exact type depends on the
   type being processed and is one of Lintian::Collect::Binary (.deb or
   .udeb), Lintian::Collect::Changes (.changes) or
   Lintian::Collect::Source (.dsc).

-  An instance of Lintian::Processable that represents the package being
   processed.

-  An instance of Lintian::ProcessableGroup that represents the other
   processables in the given group. An instance of the
   Lintian::Collect::Group is available via its "info" method.

Further arguments may be added in the future after the above mentioned
ones. Implementations should therefore ignore extra arguments beyond the
ones they know of.

If the run sub returns "normally", the check was run successfully.
Implementations should ensure the return value is undefined.

If the run sub invokes a trappable error (e.g. "die"), no further checks
are done on the package and Lintian will (eventually) exit with 1 to its
caller. The check may still be run on other packages.
