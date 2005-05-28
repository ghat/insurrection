#
# $Id$
# Copyright 2004,2005 - Michael Sinz
#
# These are the constants that define some of the subversion configuration
# within the system plus some common code that is best to be shared.
#
# Don't forget the matching insurrection.js and insurrection.xsl files.
#

## This is the base of the repositories tree.  Repositories are within
$SVN_BASE = '/home/subversion/repositories';

## This is the base of the authentication directory.  All of the authentication stuff lives here.
$SVN_AUTH = '/home/subversion/authentication';

## This is the base of the logs directory.  All of the http logs live here.
$SVN_LOGS = '/home/subversion/logs';

## This is where the svn binaries live.
$SVN_BIN = '/home/subversion/svn/bin/';

## The domain for the EMail addresses...
$EMAIL_DOMAIN = '@sinz.org';

## The default number of log entries to provide in the
## history.  If this is undef then we don't limit the
## entries.  (That would be bad)
$SVN_LOG_ENTRIES = 20;  ## Default to the last 20 entries...

## The base path to the Subversion area on the server
## This path should start with a "/" and end with one.
## (Or, just be "/" which means the tree starts are root
$SVN_URL_PATH = '/';

## The server relative path to the subversion repositories
## This path should start with "/" and end with one.
## Note that this should match the same setting in the
## insurrection.js file.
$SVN_REPOSITORIES_URL = '/svn/';

## The specific binaries we use
$SVN_CMD = $SVN_BIN . 'svn';
$SVNLOOK_CMD = $SVN_BIN . 'svnlook';
$SVNADMIN_CMD = $SVN_BIN . 'svnadmin';

1;

