Lintian release management
==========================



Preparing and doing a release
-----------------------------

Run the full test suite while the distribution is still set to
UNRELEASED to ensure everything and all tests are green.  Once
complete, replace the placeholder in the changelog with the
actual tags changed.  The following command may be helpful:

    $ private/generate-tag-summary --in-place

Then set the distribution (e.g. via `dch -r`) and run the "scripts" test
suite again.  This may appear redundant at first, but some of the
tests react differently when the distribution is not UNRELEASED
(e.g. changelog-format checks that you remembered the step above).

Build the package and run lintian on itself, cleaning up or overriding
issues that have not been fixed during development.  If you do code
changes, remember to set the distribution back to UNRELEASED!
Otherwise, some checks on the code will be skipped (e.g. critic).

Sign and upload the package.  Furthermore, prepare a signed git
tag.  This is generally done in the following way:

 * Take a copy of the signed `.changes`
 * Optionally strip the signature from it.
 * Add a tag message to the top of the file
 * Tag with `git tag <VERSION> -u <KEYID> --file <FILE>`

This method is used to provide a "trust" path between the tag and
the uploaded files.  This is also why we use the signed `.changes`
(as signing the source package changes the checksums in the `.changes`).

Once the upload has been accepted and the commit has been tagged, you
may want to "open" the next entry in the changelog.  The rationale for
this is that it makes tests go back to "regular" development mode.  At
the same time, the "tag-summary" reminder can be re-added.  See commit
a9c67f2 as an example of how it is done.


Updating lintian.debian.org
===========================

lintian.debian.org is ran by DSA, using the files provided in the `lintian-doc`
binary package.

As such, the website should be automatically updated when a new lintian release
is made.
