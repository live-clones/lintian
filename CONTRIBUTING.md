# How to contribute to Lintian

This document is intended for prospective and existing contributors.

The first section will cover how to get started for newcomers.  After
that is a section on recommended practices and additional resources.

## Getting started

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

## Running the testsuite

You can find the packages needed to run the testsuite in `debian/tests/control`.

Before running the tests, you need to be build the test packages in a separate
step:

    $ private/build-test-packages

You can then run the entire testsuite using:

    $ private/runtests

... but you can also run all the tests that use a particular tag using, for
example:

    $ private/runtests --onlyrun=tag:python-teams-merged

... or you can run of the tests associated with a particular "check" file. For
example, if you have been modifying `checks/files/ieee-data.pm`, you can limit
your test run to the related changes using:

    $ private/runtests --onlyrun=check:files/ieee-data

(Note the lack of `checks/` suffix and `.pm` suffix.)

Lastly, you can test Perl formatting using:

    $ private/runtests --onlyrun=suite:scripts


## API Docs, tutorials and the test suite documentation

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

## Submitting changes

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

## Data files

The `data`  directory contains files loaded by the `Lintian::Data` module,
specifically lists of keywords used in various Lintian checks. For all files in
this directory, blank lines are ignored, as are lines beginning with `#`.

For each list of keywords, please include in a comment the origin of the list,
any information about how to resynchronize the list with that origin, and any
special exceptions or caveats.

Files should generally be organized into subdirectory by check or by general
class of lists (for example, all lists related to `doc-base  files should go
into a `doc-base` subdirectory).

## Recommended practices

### Code style dictated by perltidy and perlcritic

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

### The "master" branch is "always releasable"

Generally the "master" branch should kept in a state where it is always
releasable.  This is an accepted practice by many other projects and
also helps us in case we suddenly need to do a release.

You are always welcome to create topic branches for publishing code that
is not ready for a release yet.

### Updating debian/changelog

Please do not manually update the `debian/changelog` file. It is created
automatically by `gbp-buildpackage` from commit messages.

However, please take time to write an effective first line of your commit
message, ensuring that it will make the sense when read in a list of changes
without any other context.

### Backport requirements

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

### Additional resources

 * perldoc [doc/tutorial/Lintian/Tutorial.pod](doc/tutorial/Lintian/Tutorial.pod)
 * perldoc [doc/README.developers](doc/README.developers)
 * [doc/releases.md](doc/releases.md)
