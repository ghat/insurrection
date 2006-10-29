#!/usr/bin/perl
#
# $Id$
# Copyright 2004-2006 - Michael Sinz
#
# This script handles getting a dump of the repository
# Note that only an admin of the repository can execute
# the dump.
#
require 'admin.pl';

## First, lets see if we are the admin of the repository...
&checkAdminMode();

## Lets check for other parameters...
my $deltas = $cgi->param('Deltas');
$deltas = 0 if (!defined $deltas);

my $head = $cgi->param('Head');
$head = 0 if (!defined $head);

## Get the compression mode
my $compress = $cgi->param('Compress');
$compress = 'gzip' if (!defined $compress);

if (defined $cgi->param('Dump'))
{
   my $dumpName = &svn_REPO();
   $dumpName .= '.deltas' if ($deltas);
   $dumpName .= '.head' if ($head);
   $dumpName .= '.svndump';

   my $rpath = $SVN_BASE . '/' . &svn_REPO();

   my $cmd = "$SVNADMIN_CMD dump '$rpath'";
   $cmd .= ' --deltas' if ($deltas);
   $cmd .= ' 2>/dev/null';

   my $type = 'application/x-svndump';

   if ($compress eq 'gzip')
   {
      $type .= '-gzip';
      $dumpName .= '.gz';
      $cmd .= ' | gzip -9';
   }

   if ($compress eq 'bz2')
   {
      $type .= '-bzip2';
      $dumpName .= '.bz2';
      $cmd .= ' | bzip2 -9 -c';
   }

   print $cgi->header('-expires' => '+1m' ,
                      '-cache-control' => 'no-cache',
                      '-type' => $type ,
                      '-Content-Disposition' => 'attachment; filename=' . $dumpName ,
                      '-Content-Description' => 'Insurrection/Subversion repository dump');

   system($cmd);

   exit 0;
}

print $cgi->redirect('-location' => '?Insurrection=admin' ,
                     '-status' => '302 Invalid path');

