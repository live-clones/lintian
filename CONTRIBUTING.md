How to contribute to Lintian
============================

This document is intended for prospective and existing contributors.

The first section will cover how to get started for newcomers.  After
that is a section on recommended practices and additional resources.

Getting started
---------------

Please either checkout the repository from [salsa.debian.org][salsa]:

    $ git clone https://salsa.debian.org/lintian/lintian.git
    $ cd lintian

Or create your own "fork" of repository [via the web interface][lintian-fork].

You will also need a number of dependencies. You can have apt install these for
you via:

    $ cd lintian
    $ apt build-dep .

Otherwise, the full list of dependencies are listed in the `Build-Depends*`
fields in the `debian/control` file.

[salsa]: https://salsa.debian.org/
[lintian-fork]: https://salsa.debian.org/lintian/lintian/forks/new

#### API Docs, tutorials and the test suite documentation

We also have some short tutorials in our API docs.  You can compile
the API documentation via:

    $ debian/rules api-doc
    $ sensible-browser doc/api.html/index.html

From there, you might want to start with "Lintian::Tutorial".  If you
prefer to use perldoc (or want to improve the tutorials), you can find
the source files for the tutorial in doc/tutorial.

The tutorial briefly covers:

 * How to write a (Lintian) check
 * How to write a test case
 * How to use the test runner (efficiently)

We are very happy to receive improvements to the tutorials or other
documentation as well.

There is also an online copy on the [Lintian web site][online-api-docs].
Note that the online copy does not necessarily reflect the API of the
current development version of Lintian.  Instead, it is the API of
Lintian when it was last updated on the Lintian web site.

[online-api-docs]: https://lintian.debian.org/library-api/index.html

Making changes
--------------

 * Make commits of logical units
 * Add a test for your change - especially if you introduce a new tag
   (run with: `debian/rules runtests onlyrun=<testname>`)
 * Check the changes for style issues
   (`debian/rules runtests onlyrun=suite:scripts`)
 * Check the changes against the test suite
   (`debian/rules runtests`)
 * Please format the commit messages with a short synopsis and (optionally) a long description.

An example commit message might be:

    Add =encoding to the POD in Lintian::Collect

    We use a UTF-8 section symbol, and the current version of Pod::Simple
    therefore requires explicitly declaring the character set.`

For more on best practices on Git commit messages, please review
[A Note About Git Commit Messages][tbaggery-git-commit] for inspiration.


[tbaggery-git-commit]: http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html

Submitting changes
------------------

Please prefer to submit your changes to Lintian by creating a
[merge-request][merge-request] on [Salsa][salsa].

Alternatively, submit your changes to the Debian Bug Tracker by reporting
a bug against the `lintian` package  On a Debian system, this can usually
be done by using `reportbug`:

    $ reportbug lintian

Otherwise send a plain text mail to "<submit@bugs.debian.org>" with
the first line being `Package: lintian`:

You are welcome to attach the changes to the bug report or link to a
git branch.  If you use attachments, please generate the changes via
the `git format-patch` command.

[merge-request]: https://salsa.debian.org/lintian/lintian/merge_requests
[salsa]: https://salsa.debian.org/

Data files
----------

The `data`  directory contains files loaded by the `Lintian::Data` module,
specifically lists of keywords used in various Lintian checks. For all files in
this directory, blank lines are ignored, as are lines beginning with `#`.

For each list of keywords, please include in a comment the origin of the list,
any information about how to resynchronize the list with that origin, and any
special exceptions or caveats.

Files should generally be organized into subdirectory by check or by general
class of lists (for example, all lists related to `doc-base  files should go
into a `doc-base` subdirectory).

Recommended practices
=====================


Code style dictated by perltidy and perlcritic
----------------------------------------------

For consistency, perltidy is used to normalize the style of the Perl
code in Lintian.  This is enforced via tests and will be checked
in all submissions.  In the cases where perltidy fails miserably,
please format the piece manually and use a "no perltidy" rule.  As
an example:

    #<<< no perltidy
    something
    that perltidy should not touch
    #>>>

Beyond perltidy, we also use perlcritic to enforce some semantic
rules.  An example rule being that we forbid the use of `grep` in
boolean context (which is better done via the `any` sub from
`List::Util`).

We have enabled enforcements of the rules, which lintian already
follows and which made sense to lintian.

The "master" branch is "always releasable"
------------------------------------------

Generally the "master" branch should kept in a state where it is always
releasable.  This is an accepted practice by many other projects and
also helps us in case we suddenly need to do a release.

You are always welcome to create topic branches for publishing code that
is not ready for a release yet.

Updating debian/changelog
-------------------------

If you are not a committer, you are welcome to leave this out and let
the committer write this bit for you.  It often makes easier for us to
merge your changes as the changelog is notorious for merge conflicts.

The general format is:

    * checks/phppear.{desc,pm}:
      + [JW] Fix typo.
      + [NT] Apply patch from Jochen Sprickerhof to skip this check if the
        package does not contain any php files.  (Closes: #805076)
    * checks/testsuite.pm:
      + [JW] Apply patch from Sean Whitton to recognise autopkgtest-pkg-elpa
        as a valid value for the Testsuite field.  (Closes: #837801)

    * data/files/php-libraries:
      + [JW] Apply patch from Marcelo Jorge Vieira to update package name
        for php-gettext.  (Closes: #837502)

    * lib/Lintian/*.pm:
      + [JW] Fix typos.
    * lib/Lintian/Tags.pm:
      + [JW, NT] Fix mojibake in UTF-8 encoded comments for overrides.
        (Closes: #833052)

Beyond the regular rules for Debian changelog files, the general
guidelines are:

 * The message is prefixed with the initials of the committer(s). New
   committers, please remember to add yourself to debian/copyright.
 * Changes are grouped by "root" folder ("checks", "data" and "lib" in
   the example above).
 * The groups are sorted by the name of the "root" folder and separated
   by a single line.
 * Inside a "root" folder, changes are grouped by files and sorted by
   the ("earliest") file in the group.
 * Changes to the test suite and the "private" directory are generally
   only documented if they have a "visible" effect (e.g. closes a
   "FTBFS" bug).
 * If a change effects more than one "root" folder, they are repeated
   for each of the related "root" folders.
 * Text after a period is followed by *two* spaces (except where it is
   part of an abbreviation like "e.g.").

Backport requirements
---------------------

There are some limits to which changes Lintian can accept as it needs
to be backportable to the current Debian stable release.  As such,
all dependencies must be satisfied in Debian stable or stable-backports.

There are several reasons for this requirement.  The two primary being:

 * Lintian is run on various debian.org hosts which are all running
   Debian stable (lintian.debian.org and ftp-master.debian.org)

 * A lot of developers use stable and will easy access to an up to date
   lintian.

Accordingly, we have continuous integration job running on
jenkins.debian.net to test this.

Additional resources
====================

 * perldoc [doc/tutorial/Lintian/Tutorial.pod](doc/tutorial/Lintian/Tutorial.pod)
 * perldoc [doc/README.developers](doc/README.developers)
 * [doc/releases.md](doc/releases.md)
