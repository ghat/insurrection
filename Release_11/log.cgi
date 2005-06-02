#!/usr/bin/perl
#
# $Id$
# Copyright 2004,2005 - Michael Sinz
#
# This script handles the display of SVN history/logs
#
require 'admin.pl';

## First, lets see if we in good standing...
&checkAuthMode();

## Get the local document URL
my $logURL = &svn_URL();

## Split the repository from the path within the repository
my $rpath = &svn_REPO();
my $opath = &svn_RPATH();

## Get the limit of revisions to show in one request
my $maxEntries = &getNumParam($cgi->param('max'));
$maxEntries = $SVN_LOG_ENTRIES if (!defined $maxEntries);
my $revcount = 1;
my @revs;

## Check if someone asked for a revision number
my $rev = '';
my $r1 = &getNumParam($cgi->param('r1'));
my $r2 = &getNumParam($cgi->param('r2'));

## If the single rev parameter is given, this means show only it
my $r0 = &getNumParam($cgi->param('r'));

## To help reduce overhead, we do not need to use svnlook to
## trace history if we were given a specific range.  This can
## significantly reduce the overhead for the request of the
## revision log in large repositories.  (Since --limit is
## not here yet and we would need it for the svnlook command
## as well.)  This has become more noticable due to the
## RSS feeds making links directly to the revision history
## of that commit.  (A good thing but it does increase
## the number of hits on the revision history display)
## Even better would be if svn log supported looking at
## past revisions based on a peg revision in the URI
## such that it would "follow" the copy automatically
## for us.  In stead, we do it manually within here
## but only when we would provide multi-page output.
if (defined $r0)
{
   $rev = "-r '$r0:$r0' ";
   $maxEntries = 1;
}
elsif (defined $r2)
{
   $r1 = 'HEAD' if (!defined $r1);
   $rev = "-r '$r1:$r2' ";
   $maxEntries = 1;
}
else
{
   ## Get the revision history list so we can count the ones we want
   ## and we can follow renames (actually, copies) through the history
   my $hcmd = $SVNLOOK_CMD . ' history';
   $hcmd .= ' -r "' . $r1 . '"' if (defined $r1);
   $hcmd .= ' "' . $SVN_BASE . '/' . $rpath . '" "' . $opath . '"';
   @revs = (`$hcmd` =~ m:(\d+)\s+(/[^\n]*):gso);
   $revcount = @revs / 2;
   $maxEntries = $revcount if (!defined $maxEntries);
   $maxEntries = $revcount if (($maxEntries > $revcount) || ($maxEntries < 1));

   ## Figure out what revisions to show...
   if ($revcount)
   {
      ## Figure out the range we need to use for the SVN LOG command.
      $r1 = $revs[0];
      $r2 = $revs[2 * ($maxEntries - 1)];
      $rev = "-r '$r1:$r2' ";
   }
}

## Now, lets build the correct command to run...
my $cmd = $SVN_CMD . ' log --non-interactive --no-auth-cache -v --xml ' . $rev . $logURL;

## What a trick - to get the broken browsers to work.
## Removes the need for XSLT...
##
## Note that the XSLT of Safari is almost working but
## not quite.  So it is listed here.
##
## What we do here is redirect the output of this
## CGI into a server-side XSLT processor when the
## client user-agent string seems to match known
## broken clients.
##
## Note that if someone expressly wants XML, the
## XMLHttp=1 attribute is needed.
##
## Note that we would like to have the real XSLT working
## as there are some things that are not available
## without it *and* the bandwidth and server load are
## much lower.  The good thing is that the top two
## browser technologies do work correctly enough to
## not need this hack.  That ends up covering 98% of
## all wed users.  (That is Mozilla/Firefox and IE)
my $needsXSLT = 1 if (&isBrokenBrowser());
my $sendType = 'text/xml; charset=utf-8';
$sendType = 'text/html' if ($needsXSLT);

my $log;
if ((defined $rpath)
   && (defined $opath)
   && ($revcount)
   && (open(LOGXML,"$cmd |")))
{
   print $cgi->header('-expires' => '+1m' ,
                      '-Cache-Control' => 'no-cache',
                      '-type' => $sendType);

   ## Note, we can just fall-through if this fails.  We would
   ## end up getting XML where we wanted HTML but if we needed
   ## HTML and the xsltproc does not exist, this is no worse
   ## than not even trying.  (And, well, what else could I do?)
   open(STDOUT,'| xsltproc insurrection.xsl -') if ($needsXSLT);

   ## We need to do a bit of processing here in order to
   ## add in our insurrection.xsl xml-stylesheet tag and to
   ## add in some attributes are not generated as part of the
   ## svn log command.
   while (<LOGXML>)
   {
      if ($_ =~ m:<log>:o)
      {
         print '<?xml-stylesheet type="text/xsl" href="' , $SVN_URL_PATH , 'insurrection.xsl"?>' , "\n"
             , "<!-- Insurrection Web Tools for Subversion: History -->\n"
             , "<!-- Copyright (c) 2004,2005 - Michael Sinz         -->\n"
             , "<!-- http://www.sinz.org/Michael.Sinz/Insurrection/ -->\n"
             , '<log repository="' , &svn_XML_Escape($rpath) , '" path="' , &svn_XML_Escape($opath) , '">' , "\n";

         ## Since we always include the last entry as the first entry on the
         ## next page, we can not support next pages with $maxEntries == 1
         ## We also do not provide "morelog" if the request was for a specific
         ## range or a single entry.
         if (($maxEntries < $revcount) && (@revs > 0) && ($maxEntries > 1))
         {
            my $nextRev = $revs[2 * ($maxEntries - 1)];
            my $nextPath = $revs[1 + (2 * ($maxEntries - 1))];

            ## Note - the complexity here is that we need to follow the revision
            ## history in case the file was copied/renamed from elsewhere.
            ## Thus, we need to take the last entry and use its path for the
            ## next log request.  If the 'svn log' took a peg revision as
            ## the URI to the repository/path and then supported the
            ## revision rage arguments, then the following of history
            ## would be oh so much easier.
            print '<morelog href="'
                ,   &svn_XML_Escape($SVN_REPOSITORIES_URL . &svn_URL_Escape($rpath . $nextPath))
                ,   '?Insurrection=log&amp;r1=' , $nextRev;
            print   '&amp;max=' , $maxEntries if ($maxEntries != $SVN_LOG_ENTRIES);
            print  '"/>' , "\n";
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
   print "Status: 404 Log Not Available\n";
   &svn_HEADER('SVN LOG - Insurrection Server');

   print '<h1>Failed to access the log</h1>'
       , '<h3>Log command:</h3>'
       , '<pre>' , $cmd , '</pre>';

   &svn_TRAILER('$Id$');
}

