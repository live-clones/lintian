# How to contribute to Lintian

This document is intended for prospective and existing contributors.

The first section will cover how to get started for newcomers.  After
that is a section on recommended practices and additional resources.

## Getting started

The best way to contribute code to Lintian is to submit merge requests
on [salsa.debian.org][salsa]. First, create an account on Salsa if you
do not have one. You need to configure at least one SSH key.

The easiest way to file merge requests on Salsa is to fork our team
repository into your private name space. That is done on the website.

Then you should clone the forked version of Lintian from your private
name space to your local machine. You can find the command for that
under a blue button that says "Clone'. Choose the git protocol (not
HTTPS).

    $ git clone git@salsa.debian.org:${your-namespace}/lintian.git
    $ cd lintian

Create a feature branch for your proposed changes.

    $ git checkout -b my-feature

### Make Lintian better

Now you can fix bugs or implement new checks.

Please commit your changes with suitable explanations in the commit
messages. You can find some examples with:

    $ git log

Please do not touch debian/changelog. We automatically update that
file at release time from commit messages via `gbp-buildpackage`.

The first line of your commit message is special. It should make sense
without any context in a list of other, unrelated changes.

### Tell us how to test your work

All new tags require unit tests. Lintian's test suite will fail unless
you provide tests for your proposed tags.

There is a way to exempt your tag from testing, but please do not do
so.

Our test specifications have two parts. One declares how to build the
test package. The other declares how to run Lintian on it.

The build instructions are almost completely parameterized. In many
cases, you will not need to copy or modify any templates. For each
test, the build specifications are located in the file
${recipe-dir}/build-spec/fill-values.

A simple one might look like this:

    Skeleton: upload-native
    Testname: pdf-in-etc
    Description: Ships a PDF file in /etc

Such a package would probably be used to trigger a tag about
documentation in a place other than /usr/share/doc. Please do not look
for this test in the test suite; it is ficticious.

For most tests, we run only the check being tested. That is why the
tests are sorted according to the check to which they belong.

Please name your tests after what they contain. Do not name them after
the tag they are testing. Many tags use two or more tests to exercise
subtle variations in the trigger conditions.

The second part of each test describes how to run Lintian and which
tags to expect. Evaluation specifications are located in the file
${recipe-dir}/eval/desc.

A simple evaluation specification might look like this:

    Testname: pdf-in-etc
    Check: documentation

As noted, this will only run the specified check. It eliminates all
nuisance tags, such as debian-watch-does-not-check-gpg-signature
(unless you are working on the check debian/watch).

Another file in that same directory shows the tags expected to be
triggered. Only tags from the selected check will show up there.

You should scrupulously examine that file to make sure your tags show
up exactly the way you want, but you do not have to write it
yourself. The test suite will do it for you during the interactive
calibration in the next step.

### Calibrate your tests

To build the test package you probably have to install all test
prerequisites from d/tests/control. Usually, that can be done with:

    $ autopkgtest -B

If anyhing else is missing, you may also have to install the build
prerequisites. That can be done with:

    $ apt build-dep .

Both of these commands have to be run with superuse privileges (root).

As you might imagine, Lintian comes with a large number of test
packages. You have to build all of them locally. It takes time the
first time around but is much faster in subsequent runs. You can build
the test packages with:

    $ private/build-test-packages

Now, please calibrate your tests. For the documentation check the
command would be:

    $ private/runtests --onlyrun=check:documentation

Make sure to select the check you are actually modifying.

The interactive calibration will add expected tags to your test
specifications. In many cases, it is best to "accept all" and examine
the changes in git. In complex cases, you can use git add -i to accept
only the ones you need.

This is a crucial step. Please make sure the expected tags are
meaningful. We also pay close attention to these tags when we look at
your merge request.

### Run the full test suite

Finally, please start the entire test suite. It will run a variety of
style and consistency tests. The most common issue is that you have to
run perltidy.

We configure perltidy in a special way. Please run it from the
repository's base directory. Otherwise it will not find the custom
configuration, and the test suite will not pass.

### Submit your merge request

Finally, please push your changes to the Lintian repo in your own name
space. You may end up doing that multiple times, It will eventually
require the force switch.

    $ git push -f

That command will respond with the single most important message in
this document. Salsa will ask you to create a merge request. Just
click the link provided in the terminal.

Your browser will open a draft merge request. For a single commit, the
text field is populated with your commit message. Otherwise, please
explain the purpose of your commit series and hit "Submit".

The push command also started the standard CI pipeline on Salsa, which
is very comprehensive. It builds Debian packages and runs autopkgtest,
among many other jobs.

We will generally not accept merge requests unless the CI pipeline
passes sucessfully. You can see the status on Salsa in two places: in
the MR and in your own repo. The pipeline takes about one hundred
minutes.

There is no need, however, to wait for Salsa CI pipeline before
submitting your merge request. If you followed all the steps above, it
will very likely pass.

## Other ways to submit changes

Please make an effort to submit your changes to Lintian by creating a
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

## Recommended practices

### The "master" branch is "always releasable"

We try to keep the "master" branch in a clean state that is suitable
for release at all times.

For topic branches that are not yet suitable for release, please point
us to your personal repository on Salsa or file a merge request with
WIP: in the title.

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
