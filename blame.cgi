#!/usr/bin/perl
#
# $Id$
# Copyright 2004,2005 - Michael Sinz
#
# This script handles the display of the "svn blame"
# output for a specific version.
#
require 'common.pl';

use CGI;

# Set up our CGI context and get some information
my $cgi = new CGI;

## Get the revision
my $rev = $cgi->param('r');
$rev = 'HEAD' if (!defined $rev);

## Get the real document info
my $docURL = &svn_URL($cgi->path_info);

## Now, lets build the correct command to run...
my $cmd = $SVN_CMD . ' blame -r ' . $rev . ' ' . $docURL;

&svn_HEADER('blame ' . $rev . ' - ' . $cgi->path_info);

print '<a class="blametitle" href="' , $SVN_URL_PATH , 'log.cgi' , $cgi->path_info , '">'
    , 'Annotation from revision ' , $rev , ' of<br/>'
    , $cgi->path_info
    , '</a>';

if (open(GETBLAME,"$cmd |"))
{
   print '<table class="blame" cellspacing="0" cellpadding="0">';

   my $lastREV = '';
   my $lastUSER = '';
   my $nl = '';
   my $count = 0;

   while (<GETBLAME>)
   {
      if ($_ =~ m:^Skipping binary file:)
      {
         print '<tr><td>Skipping binary file</td></tr>';
      }
      elsif ($_ =~ m:^\s*(\d+)\s*(\S+)\s(.*)$:)
      {
         ## Split the lines up...
         my $rev = $1;
         my $user = $2;
         my $txt = $3;

         ## Now, escape all of the stuff we need to in order to be
         ## safe HTML...
         $txt =~ s/&/&amp;/sg;
         $txt =~ s/</&lt;/sg;
         $txt =~ s/>/&gt;/sg;

         if (($lastREV != $rev) || ($lastUSER ne $user))
         {
            print '</pre></td></tr>' if ($nl ne '');

            $count++;

            print '<tr class="blameline' , ($count & 1) , '">'
                ,  '<td class="blamerev">' , $rev , '</td>'
                ,  '<td class="blameuser">' , $user , '</td>'
                ,  '<td class="blamelines"><pre>';
            $lastREV = $rev;
            $lastUSER = $user;
            $nl = '';
         }
         print $nl , $txt;
         $nl = "\n";
      }
   }

   print '</pre></td></tr>' if ($nl ne '');
   print '</table>';
}

&svn_TRAILER('$Id$',$cgi->remote_user);

