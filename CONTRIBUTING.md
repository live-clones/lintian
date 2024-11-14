# How to contribute to Lintian

This document is intended for prospective and existing contributors.

The first section will cover how to get started for newcomers. After
that is a section on recommended practices and additional resources.

## Getting started

The best way to contribute code to Lintian is to submit merge requests
on [salsa.debian.org][salsa]. First, create an account on Salsa if you
do not have one. You need to configure at least one SSH key.

The easiest way to file merge requests on Salsa is to fork our team
repository into your private namespace. That is done on the Salsa
website.

Then you should clone the forked version of Lintian from your private
namespace to your local machine. You can find the command for that
under a blue button that says "Clone". Choose the git protocol (not
HTTPS).

```shell
git clone git@salsa.debian.org:${your-namespace}/lintian.git
cd lintian
```

Create a feature branch for your proposed changes.

```shell
git checkout -b my-feature
```

### Improve Lintian

Now you can fix bugs or implement new features.

Please commit your changes with suitable explanations in the commit
messages. You can find some examples with:

```shell
git log
```

Please do not touch `debian/changelog`. We automatically update that
file at release time from commit messages via `gbp dch`.

The first line of your commit message is special. It should make sense
without any context in a list of other, unrelated changes.

### Tell us how to test your work

All new tags require unit tests. Lintian's test suite will fail unless
you provide tests for your proposed tags.

**There is a way to exempt your tag from testing.**

Most tests only run a specific lintian 'check'. Please name your tests
after this check: do not name them after the tag they are testing
because many tags need two or more tests to exercise subtle variations
in the trigger conditions.

Test specifications have two parts, build specifications and
evaluation specifications. Build specifications tell the testsuite how
to build a test package, and evaluation specifications declare how to
run Lintian on the package and say what the expected output is.

Build specifications are located in the directory
`t/recipes/path/to/test/build-spec/`. This must contain:

* A partial debian/ directory that includes as little packaging files
  as possible
* An optional 'orig' directory containing upstream files (if any are
  needed to trigger the tag)
* A file called 'fill-values' that tells the test suite how to use
  existing template to 'fill in' anything not included in debian/

For most tests, debian/ will be very minimal indeed. A simple
'fill-values' might look like this:

    Skeleton: upload-native
    Testname: pdf-in-etc
    Description: Ships a PDF file in /etc

This will use the 'upload-native' template to create a native package
with the given 'Description'.  The 'debian' directory would have a
one-line 'install' file putting some PDF documentation in /etc, and a
PDF file would be included in orig. (Please do not look for this test
in the test suite; it is just an example).

Evaluation specifications are located in the directory
't/recipes/path/to/test/eval/'. These describe how to run Lintian and
which output (tags, exit code) to expect.

The main file is 'desc'. A simple evaluation specification might look
like this:

    Testname: pdf-in-etc
    Check: documentation

As noted, this will only run the specified 'documentation' check. This
keeps output to a minimum so you do not get nuisance tags, such as
debian-watch-does-not-check-gpg-signature (unless you are working on
the a check for debian/watch). The contents of the 'Testname' field
must match the directory name.

A 'hints' file in the eval directory contains the tags that lintian is
expected to be produce when run on the test package. Only tags from
the selected 'check' should be included.

You should scrupulously examine the 'hints' to make sure your tags
show up exactly the way you want, but you do not have to write it
yourself. The test suite will help you write this during the
interactive calibration described in the next step.

Further details are in the file [t/recipes/README](t/recipes/README).

### Preparing to run the test suite

To run the testsuite you probably have to install all testsuite
prerequisites from Lintian's `debian/tests/control`. This can be done
with:

```shell
autopkgtest -B
```

You may also have to install the build dependencies with:

```shell
apt build-dep .
```

Both of these commands have to be run with root privileges.

### Running the testsuite

To run all tests run

```shell
private/runtests
```

This takes a long time the first time you run it because Lintian has a
large number of tests each building its own test package. The
packages are built locally (in `debian/test-out/`) and reused so
subsequent runs are much faster.

To run a subset of tests, use `--onlyrun`:

```shell
private/runtests --onlyrun=check:documentation
```

This runs all tests that have 'Check: documentation' in their
'eval/desc' file. Alternatively `private/runtests --onlyrun=test:name`
will run a single test with 'Testname: name'. Running
`private/runtests --help` will show you further options.


### Calibrating tests to fix test failures

If tests fail, the testsuite will use an interactive 'calibration'
process to help you write or amend a 'hints' file. Simply follow
the instructions on the screen. In many cases, it is best to "accept
all" and examine the changes in git. In complex cases, you can use
`git add -i` to stage only the changes you need.

This is a crucial step when adding a new test. Please make sure the
expected tags are correct. We pay close attention to these tags when
we look at your merge request.

### Run the full test suite

Once your test is correct and passing, please ensure the entire test
suite passes. This includes a variety of style and consistency
tests.

The most common issue detected is that you have to run perltidy. We
configure perltidy in a special way. Please run it from the
repository's base directory. Otherwise it will not find the custom
configuration, and the test suite will not pass.

### Run perltidy

The program `perltidy` is provided by the package [perltidy](https://packages.debian.org/perltidy).

The program `prove` is provided by the package [perl](https://packages.debian.org/perl).

#### On all files

```shell
prove -l t/scripts/01-critic/
```

### On recently changed files

On the 10 last commits

```shell
git diff --name-only HEAD~10 HEAD | grep -F ".pm" | xargs perltidy -b
```

### Submit a merge request

Once all the above is done, please push your changes to your Lintian
fork on Salsa.

You may end up doing that multiple times: use `git push -fv` to keep
the git history simple.

After each push you will be shown a link to create a merge
request. Just click the link provided in the terminal. Your browser
will open a draft merge request. For a single commit, the text field
is populated with your commit message. Otherwise, please explain the
purpose of your commit series and hit "Submit".

The push command also started the standard CI pipeline on Salsa, which
is very comprehensive. It builds Debian packages and runs autopkgtest,
among many other jobs.

We will generally not accept merge requests unless the CI pipeline
passes successfully. You can see the status on Salsa in two places: in
the MR and in your own repo. The pipeline takes about one hundred
minutes.

There is no need, however, to wait for Salsa CI pipeline before
submitting your merge request. If you followed all the steps above, it
will very likely pass.

## Other ways to submit changes

Please make an effort to submit your changes to Lintian by creating a
[mmerge request][merge-request] on [Salsa][salsa]. When submitting on
Salsa, ensure you have Salsa CI enabled and if the Lintian test suite
reports any failures, please review them.

Alternatively, submit your changes to the Debian Bug Tracker by reporting
a bug against the `lintian` package  On a Debian system, this can usually
be done by using `reportbug`:

```shell
reportbug lintian
```

Otherwise send a plain text mail to <submit@bugs.debian.org> with
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

There are several reasons for this requirement. The two main ones are:

* Lintian is run on various debian.org hosts which are all running
  Debian stable (ftp-master.debian.org)

* Many developers use stable and will want easy access to an up to date
  Lintian.

Accordingly, we have continuous integration job running on
jenkins.debian.net to test this.

### Additional resources

* perldoc [doc/tutorial/Lintian/Tutorial.pod](doc/tutorial/Lintian/Tutorial.pod)
* perldoc [doc/README.developers](doc/README.developers)
* [doc/releases.md](doc/releases.md)

## Making a release

First ensure that test suite pass both locally and on Salsa.

Then make a release commit by running the following command
(make sure the `DEBEMAIL` and `DEBFULLNAME` variables are set)

```shell
gbp dch -R --postedit="private/generate-tag-summary --in-place"
```

Check if commit message and changelog are in good shape (edit if needed
and amend commit). Then build as usual.

When lintian hit unstable or experimental, add tag using `gbp tag`
and open a new version by:

```shell
private/generate-tag-summary --in-place
```
