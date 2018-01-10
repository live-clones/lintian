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


To update lintian on lintian.debian.org, please see the README in
/srv/lintian.debian.org on lintian.debian.org.  NOTE: if Lintian has
obtained any new dependencies, these must be installed by DSA before
updating lintian.debian.org (send a patch to DSA for their metapackage
for lintian.debian.org).


Updating lintian.debian.org
===========================

Once a new release is done and tagged, we can update the installation
on archive-wide processing server that generates "lintian.debian.org".
Historically, this server was the same as "lintian.debian.org".
However, these days the archive-wide processing happens on a separate
server called:

  lindsay.debian.org
  (DD-accessible)

In the rest of the this document, we will refer to this as the lintian-host.


The update is done in the following steps:

Step 1
------

Ensure that any new dependencies are installed.  These must be
installed by DSA before updating lintian.debian.org (send a patch to
DSA for their metapackage for lintian.debian.org).

Often there are no new dependencies meaning that this step can be
omitted.  Please remember that you can request the dependencies before
the lintian release.

Step 2
------

Login to the lintian-host and ensure that lintian is not currectly
performing an archive-wide run and that you have "plenty" of time to
complete the upgrade.  The entire upgrade can be done in less than 5
minutes (but you may want to have a "slightly" larger window the first
few times).

You can find lintian's crontab via either:

    sudo -ulintian crontab -l

OR

    less /srv/lintian.debian.org/etc/cron

If the archive-wide run is currently active, check the harness log
(`tail -f /srv/lintian.debian.org/logs/harness.log`).

 1. If lintian is processing packages, then send a SIGTERM to the
    "reporting-lintian-harness" process and it will gracefully
    terminate lintian and commit the latest changes.  A few seconds
    after the signal has been sent, reporting-lintian-harness should
    emit something like:

         [2018-01-07T14:26:25]: Signal SIGTERM acknowledged[...]

 1. If "reporting-sync-state" is running then either kill it and
    "harness" (if you do not mind triggering an error and possible
    cron-noise).  Alternatively, wait for "reporting-lintian-harness"
    to start and kill it once lintian starts processing packages.

 1. If "reporting-html-reports" is running, then just wait the 5-10
    minutes it takes for the entire run to complete.  Otherwise, we
    might end up with a broken report.



Now that we are sure the lintian is not running and will not start in
the middle of the upgrade, we can perform the actual upgrade.

    cd /srv/lintian.debian.org/lintian
    # Reset the directory in case there are out of band patches
    # - alternative being "sudo -ulintian git stash" as long as you clean it up
    sudo -ulintian git reset --hard
    sudo -ulintian git fetch
    # e.g. sudo -ulintian git checkout 2.5.67
    sudo -ulintian git checkout $LINTIAN_RELEASE_TAG

    # Update the manual + manpages
    sudo -ulintian debian/rules clean
    sudo -ulintian debian/rules rebuild-lintian.debian.org

With this, the upgrade is complete.  If the reporting framework needs
additional configuration, please remember to update
`/srv/lintian.debian.org/config.yaml` (Note it is *not* the one in the
reporting directory).
