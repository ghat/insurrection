#!/usr/bin/perl
#
# $Id$
# Copyright 2004,2005 - Michael Sinz
#
# This script handles the display of SVN history/logs
#
require 'common.pl';

use CGI;

# Set up our CGI context and get some information
my $cgi = new CGI;

## Get the local document URL
my $logURL = &svn_URL($cgi->path_info);

## Split the repository from the path within the repository
my $rpath = &svn_REPO($cgi->path_info);
my $opath = &svn_RPATH($cgi->path_info);

## Check if someone asked for a revision number
my $rev = '';
my $r1 = $cgi->param('r1');
my $r2 = $cgi->param('r2');

## Get the revision history list so we can count the ones we want...
my $hcmd = $SVNLOOK_CMD . ' history';
$hcmd .= ' -r "' . $r1 . '"' if (defined $r1);
$hcmd .= ' "' . $SVN_BASE . '/' . $rpath . '" "' . $opath . '"';
my @revs = (`$hcmd` =~ m:(\d+)\s+(/[^\n]+):gs);
my $revcount = @revs / 2;

## Check for a limit...
my $maxEntries = $cgi->param('max');
$maxEntries = $SVN_LOG_ENTRIES if (!defined $maxEntries);
$maxEntries = $revcount if (!defined $maxEntries);
$maxEntries = $revcount if (($maxEntries > $revcount) || ($maxEntries < 1));

## Figure out what revisions to show...
if ($revcount)
{
   ## Figure out the range we need to use for the SVN LOG command.
   $r1 = $revs[0];
   if (!defined $r2)
   {
      $r2 = $revs[2 * ($maxEntries - 1)];
   }
   $rev = "-r '$r1:$r2' ";
}

## Now, lets build the correct command to run...
my $cmd = $SVN_CMD . ' log -v --xml ' . $rev . $logURL;

my $log;
if ((defined $rpath)
   && (defined $opath)
   && (@revs > 0)
   && (open(LOGXML,"$cmd |")))
{
   print "Expires: Fri Dec 31 19:00:00 1999\n"
       , "Cache-Control: no-cache\n"
       , "Content-type: text/xml\n"
       , "\n";

   while (<LOGXML>)
   {
      if ($_ =~ m:<log>:)
      {
         print '<?xml-stylesheet type="text/xsl" href="' , $SVN_URL_PATH , 'log.xsl"?>' , "\n";
         print '<log repository="' , $rpath , '" path="' , $opath , '">' , "\n";

         if ($maxEntries < $revcount)
         {
            my $nextRev = $revs[2 * ($maxEntries - 1)];
            my $nextPath = $revs[1 + (2 * ($maxEntries - 1))];
            print '<morelog href="' , $cgi->url , '/' , $rpath , $nextPath , '?r1=' , $nextRev , '&amp;max=' , $maxEntries , '"/>'
                , "\n";
         }
      }
      else
      {
         print $_;
      }
   }
   close(LOGXML);
}
else
{
   &svn_HEADER('SVN LOG - Subversion Server');

   print '<h1>Failed to access the log</h1>'
       , '<h3>Log command:</h3>'
       , '<pre>' , $cmd , '</pre>';

   &svn_TRAILER('$Id$',$cgi->remote_user);
}

