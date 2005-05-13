#!/usr/bin/perl
#
# $Id$
# Copyright 2004,2005 - Michael Sinz
#
# This script handles the display of the "svn blame"
# output for a specific version.
#
require 'admin.pl';

## First, lets see if we in good standing...
&checkAuthMode();

## Get the revision
my $rev = &getNumParam($cgi->param('r'));
$rev = 'HEAD' if (!defined $rev);

## Get the real document info
my $docURL = &svn_URL($cgi->path_info);

## The URL to get a history log entry.
my $getLog = &svn_URL_Escape($SVN_REPOSITORIES_URL . &svn_REPO($cgi->path_info) . &svn_RPATH($cgi->path_info)) . '?Insurrection=log';

## Now, lets build the correct command to run...
my $cmd = $SVN_CMD . ' blame --non-interactive --no-auth-cache -r ' . $rev . ' ' . $docURL;

&svn_HEADER('Annotate ' . $rev . ' - ' . $cgi->path_info);

print '<a class="blametitle" href="' , $getLog , '">'
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

         if (($lastREV != $rev) || ($lastUSER ne $user))
         {
            print '</tt></td></tr>' if ($nl ne '');

            $count++;

            print '<tr class="blameline' , ($count & 1) , '"'
                ,     ' title="Show commit log for revision ' , $rev , '"'
                ,     ' onclick="window.open(\'' , $getLog , '&amp;r=' , $rev , '\')"'
                ,     '>'
                ,  '<td class="blamerev">' , $rev , '</td>'
                ,  '<td class="blameuser">' , &svn_XML_Escape($user) , '</td>'
                ,  '<td class="blamelines"><tt>';
            $lastREV = $rev;
            $lastUSER = $user;
            $nl = '';
         }
         print $nl , &svn_XML_Escape($txt);
         $nl = "\n";
      }
   }

   print '</tt></td></tr>' if ($nl ne '');
   print '</table>';
}

&svn_TRAILER('$Id$');

