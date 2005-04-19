#!/usr/bin/perl
#
# $Id$
# Copyright 2004,2005 - Michael Sinz
#
# This script handles the display of SVN diff
#
require 'common.pl';

use CGI;

# Set up our CGI context and get some information
my $cgi = new CGI;

## Get the revision
my $rev1 = $cgi->param('r1');
$rev = 'HEAD' if (!defined $rev1);

my $rev2 = $cgi->param('r2');
$rev = "PREV" if (!defined $rev2);

## Get the real document info
my $docURL = &svn_URL($cgi->path_info);

## Now, lets get the diff (or at least try to)
my $cmd = $SVN_CMD . ' diff --notice-ancestry "' . $docURL . '@' . $rev1 . '" "' . $docURL . '@' . $rev2 . '"';

my $results;
if (open(GETDIFF,"$cmd |"))
{
   $results = join("",<GETDIFF>);
   close(GETDIFF);
}

if (defined $results)
{
   ## Now, escape all of the stuff we need to in order to be
   ## safe HTML...
   $results =~ s/&/&amp;/sg;
   $results =~ s/</&lt;/sg;
   $results =~ s/>/&gt;/sg;

   ## Wrap the whole thing in a pre tag
   $results = '<pre class="diff">' . "\n" . $results . '</pre>';

   ## Next, lets style the diff "Index:" section
   $results =~ s|\nIndex(:.*?)\n\=+\n|<div class="diffindex">diff$1</div>|sg;

   ## Style the property differences
   ## This is a bit difficult for the directory differences
   ## since you can have a batch of differences only in properties.
   ## This is partially why this bit of regexp is as complex as it is.
   $results =~ s|\n+(Property changes[^\n]+)(\n[^<]*?)(?=\nProperty changes)|\n<div class="diffindex">$1</div><div class="diffprop">$2</div>\n|sg;
   $results =~ s|\n+(Property changes[^\n]+)(\n[^<]*)|\n<div class="diffindex">$1</div><div class="diffprop">$2</div>|sg;
   $results =~ s|</div>\n|</div>|sg;
   $results =~ s|\n_+\n||sg;
   $results =~ s|(?<=[\n>])(   \- [^<\n]+)|<div class="diff1">$1</div>|g;
   $results =~ s|(?<=[\n>])(   \+ [^<\n]+)|<div class="diff2">$1</div>|g;
   $results =~ s|</div>\n+</div>|</div></div>|sg;

   ## Finally, lets style the line delete/add lines
   $results =~ s|(?<=[\n>])(\-[^<\n]*)|<div class="diff1">$1</div>|g;
   $results =~ s|(?<=[\n>])(\+[^<\n]*)|<div class="diff2">$1</div>|g;

   ## Style the diff line add/delete sections
   $results =~ s|(?<=[\n>])(\@\@[^<\n]*)|<div class="diff3">$1</div>|g;

   ## Clean up extra line enders
   $results =~ s|</div>\n|</div>|sg;
}
else
{
   $results = '<h1>No difference returned</h1>';
}


&svn_HEADER('diff ' . $rev1 . ':' . $rev2 . ' - ' . $cgi->path_info);

print '<a class="difftitle" href="' , $SVN_URL_PATH , 'log.cgi' , $cgi->path_info , '">'
    , 'Differences from revision ' , $rev1 , ' to ' , $rev2 , '<br/>'
    , $cgi->path_info
    , '</a>';

print $results;

&svn_TRAILER('$Id$',$cgi->remote_user);

