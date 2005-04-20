#
# $Id$
# Copyright 2004,2005 - Michael Sinz
#
# These are the constants that define some of the subversion configuration
# within the system plus some common code that is best to be shared.
#
# Don't forget the matching insurrection.js and insurrection.xml files.
#

## This is the base of the repositories tree.  Repositories are within
$SVN_BASE = '/home/equine/private/subversion/repositories';

## This is where the svn binaries live.
$SVN_BIN = '/home/equine/private/subversion/svn/bin/';

## The domain for the EMail addresses...
$EMAIL_DOMAIN = '@sinz.com';

## The official URL to the this server
$SVN_URL = 'http://svn.sinz.com:8000';

## The default number of log entries to provide in the
## history.  If this is undef then we don't limit the
## entries.
$SVN_LOG_ENTRIES = 20;  ## Default to the last 20 entries...

## The base path to the Subversion area on the server
## This path should start with a "/" and end with one.
## (Or, just be "/" which means the tree starts are root
$SVN_URL_PATH = '/';

## The specific binaries we use
$SVN_CMD = $SVN_BIN . 'svn';
$SVNLOOK_CMD = $SVN_BIN . 'svnlook';

return 1;

