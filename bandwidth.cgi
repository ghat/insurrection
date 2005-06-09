#!/usr/bin/perl
#
# $Id$
# Copyright 2004,2005 - Michael Sinz
#
# This script displays the bandwidth used for
# the given repository.  Note only repository
# admins or the global admin can access this page.
#
require 'admin.pl';

## First, lets see if we in good standing for this...
&checkAdminMode();

## Where the usage history sumary files are stored
my $USAGE_DIR = $SVN_LOGS . '/usage-history';

## Load upto n-days into the past for this history
## Note that only admins can see more than 1 month worth.
my $MAX_HISTORY = 400;

my $isAdmin = &isAdminMember('Admin',$AuthUser);

my $max_history = $cgi->param('History');
$max_history = $MAX_HISTORY if ((!defined $max_history) || (!$isAdmin));

## Check if we are to show details
my $showDetails = $cgi->param('Details');

## The repository we are playing with...
my $repo = &svn_REPO();
$repo = '' if ($repo eq '/');
if ($repo eq '')
{
   print $cgi->redirect('-location' => $SVN_URL_PATH,
                        '-status' => '302 Invalid path');
   exit 0;
}

## Check for the raw details information - we are rather strict in the
## way it needs to look.
my ($raw) = (&svn_RPATH =~ m:/\.raw-details\./([a-z][a-z0-9_.]+)$:o);

## Check to make sure that there is repository data available...
if ((!(-d "$USAGE_DIR/$repo/stats")) || (!defined $raw))
{
   print $cgi->redirect('-location' => $SVN_URL_PATH,
                        '-status' => '302 Invalid path');
   exit 0;
}

## Try to open the given URL
if (open(RAW,"<$USAGE_DIR/$repo/stats/$raw"))
{
   if ($raw =~ m:.html$:o)
   {
      ## Ahh, the HTML - I need to clean it up a bit...
      my $html = join('',<RAW>);
      close(RAW);

      ## Rip out just we don't want
      $html =~ s|.*<BODY[^>]*>||sgo;
      $html =~ s|</BODY[^>]*>.*||sgo;
      $html =~ s|<P>.<HR>.<TABLE.*||sgo;

      ## Make all of the references to URLs relative to the server...
      $html =~ s|http://Repository\s$repo/|/|sg;

      ## Oh, and all local links and images need the extra parameter if
      ## they are not already done
      $html =~ s:(HREF=|SRC=)"(?!#)(\./)?([^/"]+)":$1"$3?Insurrection=bandwidth":sgo;

      $html =~ s|<H2>(.*?)</H2>|<div style="text-align: center; font-weight: bold; font-size: 20pt;">$1</div>|so;
      $html =~ s|<SMALL><STRONG>(.*?)</STRONG></SMALL>|<div style="text-align: right; font-size: 10pt;">$1</div>|so;

      ## Last bit of fixup...
      $html =~ s|<CENTER>.<HR>(.*)</CENTER>|<div style="background: #EEEEEE; border: 1px black solid; margin-top: 2px; padding: 2px;"><CENTER>$1</CENTER></div>|so;

      &svn_HEADER_oldHTML('Raw Details: ' . $repo);
      print "\n<!-- Begin: HTML generated via legacy software -->\n";
      print $html;
      print "\n<!-- End: HTML generated via legacy software -->\n";

      &svn_TRAILER('$Id$');
      exit 0;
   }
   else
   {
      ## Unknown type, so just send it...
      print $cgi->header('-type' => 'application/octet-stream') , <RAW>;
      close(RAW);
      exit 0;
   }
}
else
{
   print $cgi->redirect('-status' => '404 Invalid path');
   exit 0;
}

&svn_TRAILER('$Id$');

