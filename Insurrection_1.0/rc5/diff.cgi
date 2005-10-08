#!/usr/bin/perl
#
# $Id$
# Copyright 2004,2005 - Michael Sinz
#
# This script handles the display of SVN diff
#
require 'admin.pl';

## First, lets see if we in good standing...
&checkAuthMode();

## Get the revision
my $rev1 = &getNumParam($cgi->param('r1'));
$rev1 = 'HEAD' if (!defined $rev1);

my $rev2 = &getNumParam($cgi->param('r2'));
$rev2 = "HEAD" if (!defined $rev2);

## Get the local document URL
my $docURL = &svn_URL();

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
      $patchName =~ s|^/*||o;

      ## Change '/' to '_'
      $patchName =~ s|/|_|go;

      ## A patch does not expire easily since they are always
      ## to specific revisions and thus should not change...
      print $cgi->header('-expires' => '+1d' ,
                         '-type' => 'text/patch' ,
                         '-Content-Disposition' => 'attachment; filename=' . $patchName ,
                         '-Content-Description' => 'Insurrection/Subversion generated patch' ,
                         '-Content-Length' => length($results));

      print $results;

      exit 0;
   }

   ## Now, escape all of the stuff we need to in order to be
   ## safe HTML...
   $results = &svn_XML_Escape($results);

   ## Wrap the whole thing in a pre tag
   $results = '<div class="diff">' . "\n" . $results . '</div>';

   ## Next, lets style the diff "Index:" section
   $results =~ s|\nIndex(:.*?)\n\=+\n|<div class="diffindex">diff$1</div>|sgo;

   ## Style the property differences
   ## This is a bit difficult for the directory differences
   ## since you can have a batch of differences only in properties.
   ## This is partially why this bit of regexp is as complex as it is.
   $results =~ s|\n+(Property changes[^\n]+)(\n[^<]*?)(?=\nProperty changes)|\n<div class="diffindex">$1</div><div class="diffprop">$2</div>\n|sgo;
   $results =~ s|\n+(Property changes[^\n]+)(\n[^<]*)|\n<div class="diffindex">$1</div><div class="diffprop">$2</div>|sgo;
   $results =~ s|</div>\n|</div>|sgo;
   $results =~ s|\n_+\n||sgo;
   $results =~ s|(?<=[\n>])(   \- [^<\n]+)|<div class="diff1">$1</div>|go;
   $results =~ s|(?<=[\n>])(   \+ [^<\n]+)|<div class="diff2">$1</div>|go;
   $results =~ s|</div>\n+</div>|</div></div>|sgo;

   ## Finally, lets style the line context/delete/add lines
   ## Note, that while we do style the div correctly for monospaced
   ## characters, this does not always take so we add the <tt></tt> tag
   ## to work around the "don't override fonts" option in many browsers.
   $results =~ s|(?<=[\n>])(\s[^<\n]*)|<div class="diff0"><tt>$1</tt></div>|go;
   $results =~ s|(?<=[\n>])(\-[^<\n]*)|<div class="diff1"><tt>$1</tt></div>|go;
   $results =~ s|(?<=[\n>])(\+[^<\n]*)|<div class="diff2"><tt>$1</tt></div>|go;

   ## Style the diff line add/delete sections
   $results =~ s|(?<=[\n>])(\@\@[^<\n]*)|<div class="diff3">$1</div>|go;
}
else
{
   $results = '<h1>No difference returned</h1>';
}

&svn_HEADER('diff ' . $rev1 . ':' . $rev2 . ' - ' . $cgi->path_info);

## Put a link at the top to get the results as a patch
print '<a class="difftitle" href="?Insurrection=diff&amp;getpatch=1&amp;r1=' , $rev1 , '&amp;r2=' , $rev2 , '">'
    , 'Download patch file for revision ' , $rev1 , ' to ' , $rev2 , '<br/>'
    , 'of ' , &svn_XML_Escape($cgi->path_info)
    , '</a>';

print $results;

&svn_TRAILER('$Id$');

