#!/usr/bin/perl
#
# $Id$
# Copyright 2004,2005 - Michael Sinz
#
# This script handles the display of SVN diff
#
require 'admin.pl';

## First, lets see if we are allowed to look here:
&checkAuthPath($cgi->path_info);

## Get the revision
my $rev1 = $cgi->param('r1');
$rev1 = 'HEAD' if (!defined $rev1);

my $rev2 = $cgi->param('r2');
$rev2 = "HEAD" if (!defined $rev2);

## Get the real document info
my $docURL = &svn_URL($cgi->path_info);

## Now, lets get the diff (or at least try to)
my $cmd = $SVN_CMD . ' diff --non-interactive --no-auth-cache --notice-ancestry "' . $docURL . '@' . $rev1 . '" "' . $docURL . '@' . $rev2 . '"';

my $results;
if (open(GETDIFF,"$cmd |"))
{
   $results = join("",<GETDIFF>);
   close(GETDIFF);
}

if (defined $results)
{
   ## Ugly - if there was a request to get diff as a patch, we
   ## short-curcuit all of this and just output the headers as
   ## needed.
   if ($cgi->param('getpatch') eq '1')
   {
      my $patchName = $cgi->path_info . '-r.' . $rev1 . '-r.' . $rev2 . '.patch';

      ## Get rid of leading '/'
      $patchName =~ s|^/*||;

      ## Change '/' to '_'
      $patchName =~ s|/|_|g;

      print 'Expires: Fri Dec 31 19:00:00 1999' , "\n"
          , 'Cache-Control: no-cache' , "\n"
          , 'Content-Length: ' , length($results) , "\n"
          , 'Content-Type: text/patch' , "\n"
          , 'Content-Disposition: attachment; filename=' , $patchName , "\n"
          , 'Content-Description: Insurrection/Subversion generated patch' , "\n"
          , "\n"
          , $results;

      exit 0;
   }

   ## Now, escape all of the stuff we need to in order to be
   ## safe HTML...
   $results = &svn_XML_Escape($results);

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

   ## Finally, add a link at the top to get the results as a diff/patch

}
else
{
   $results = '<h1>No difference returned</h1>';
}


&svn_HEADER('diff ' . $rev1 . ':' . $rev2 . ' - ' . $cgi->path_info);

print '<a class="difftitle" href="?getpatch=1&amp;r1=' , $rev1 , '&amp;r2=' , $rev2 , '">'
    , 'Download patch file for revision ' , $rev1 , ' to ' , $rev2 , '<br/>'
    , 'of ' , &svn_XML_Escape($cgi->path_info)
    , '</a>';

print $results;

&svn_TRAILER('$Id$',$cgi->remote_user);

