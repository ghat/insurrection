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

## Get the system admin account information...
my $isAdmin = &isAdminMember('Admin',$AuthUser);

## The repository we are playing with...
my $repo = &svn_REPO();
$repo = '' if ($repo eq '/');

## If the repository is flagged as no-stats and we are not
## the system administarator, don't let them in...
if (($repo eq '') || ((!$isAdmin) && (-f "$SVN_BASE/$repo/no-stats.flag")))
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
      $html =~ s|^.*<BODY[^>]*>||sgo;
      $html =~ s|</BODY[^>]*>.*$||sgo;
      $html =~ s|<P>.<HR>.<TABLE.*||sgo;

      ## Make all of the references to URLs relative to the server...
      $html =~ s|http://Repository\s$repo/|/|sg;

      ## Oh, and all local links and images need the extra parameter if
      ## they are not already done
      $html =~ s:(HREF=|SRC=)"(?!#)(\./)?([^/"]+)":$1"$3?Insurrection=bandwidth":sgo;

      ## Some headers need changing...
      $html =~ s|\s*<H2>\s*(.*?)\s*</H2>\s*|<div style="text-align: center; font-weight: bold; font-size: 20pt;">$1</div>|so;
      $html =~ s|\s*<SMALL><STRONG>\s*(.*?)\s*</STRONG></SMALL>\s*|<div style="margin-bottom: 2px; text-align: right; font-size: 10pt;">$1</div>|so;

      ## Oh, all of those bad blank rows with not enough columns - just throw them out
      $html =~ s|\s*<TR>\s*<TH HEIGHT=\d+>\s*</TH>\s*</TR>\s*||sgo;

      ## Last bit of fixup...
      ## If this page has the stuff at the top for different sections,
      ## lets use that and my nice tabs.js to get the whole thing into
      ## a tab-like display.  All client side tricks, which is nice too.
      if ($html =~ m|<SMALL>\s*<A HREF="#.*?</SMALL>|so)
      {
         ## Trim away junk...
         $html =~ s|\s*<CENTER>\s*<HR>(?:\s*<P>)?\s*(.*?)\s*</CENTER>\s*$|$1|so;

         ## Build our tab-based page...
         my @tabs = ($html =~ m|<A HREF="#([^"]+)">\[(.*?)\]</A>|sgo);

         my $insertText = '<script type="text/javascript" language="JavaScript" src="/tabs.js"></script>'
                        . '<script type="text/javascript" language="JavaScript"><!--' . "\n"
                        . 'startTabSet("bw",["Monthly"';

         for (my $i=1; $i < @tabs; $i+=2)
         {
            ## Get rid of the "statistics" bit
            $tabs[$i] =~ s/\s.*//;

            $insertText .= ',"' . $tabs[$i] . '"';
         }
         $insertText .= ']);'
                      . 'startTabSetPage("bw");'
                      . '//--></script><div class="bandwidth">';

         $html =~ s|<SMALL>\s*<A HREF="#.*?</SMALL>\s*<P>|$insertText|s;

         ## Each page in the tabset needs one of these...
         my $nextPage = '</div><script type="text/javascript" language="JavaScript"><!--' . "\n"
                      . 'startTabSetPage("bw");'
                      . '//--></script><div class="bandwidth">';

         $insertText = '';
         for (my $i=0; $i < @tabs; $i+=2)
         {
            my $findText = '<A NAME="' . $tabs[$i] . '"></A>';

            $insertText .= $nextPage;

            ## If we find that section, clear out the insertText...
            ## We need to keep track of non-used pages as they need to
            ## be used in same order as the array used during init.
            $insertText = '' if ($html =~ s/<P>\s*$findText/$insertText/s);
         }

         ## I want to tweek some of the tables a bit...
         $html =~ s|<TABLE (?!BGCOLOR)|<TABLE BGCOLOR="#DDDDDD" |sgo;
         $html =~ s|<TR>|<TR BGCOLOR="#FFFFFF">|sgo;

         $html .= $insertText
                . '</div><script type="text/javascript" language="JavaScript"><!--' . "\n"
                . 'endTabSet("bw");'
                . '//--></script>';
      }
      else
      {
         $html =~ s|\s*<CENTER>\s*<HR>(?:\s*<P>)?\s*(.*?)\s*(?:<P>\s*)?</CENTER>\s*$|<div style="background: #EEEEEE; border: 1px black solid; margin-top: 2px; padding: 0.5em;"><div class="bandwidth">$1</div></div>|so;
         $html =~ s|</CENTER><PRE>|<PRE>|sgo;
      }

      &svn_HEADER_oldHTML('Raw Details: ' . $repo);

      print "\n<!-- Begin: HTML generated via legacy software -->\n";
      print $html;
      print "\n<!-- End: HTML generated via legacy software -->\n\n";

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

