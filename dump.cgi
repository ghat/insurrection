#!/usr/bin/perl
#
# $Id$
# Copyright 2004,2005 - Michael Sinz
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

## Now, lets check if this is a "go"
if ($cgi->param('Dump') eq 'go')
{
   my $dumpName = &svn_REPO();
   $dumpName .= '.deltas' if ($deltas);
   $dumpName .= '.svndump.gz';

   my $rpath = $SVN_BASE . '/' . &svn_REPO();

   my $cmd = "$SVNADMIN_CMD dump '$rpath'";
   $cmd .= ' --deltas' if ($deltas);
   $cmd .= ' 2>/dev/null | gzip -9';

   print $cgi->header('-expires' => '+1m' ,
                      '-cache-control' => 'no-cache',
                      '-type' => 'application/octet-stream' ,
                      '-Content-Disposition' => 'attachment; filename=' . $dumpName ,
                      '-Content-Description' => 'Insurrection/Subversion repository dump');

   print `$cmd`;

   exit 0;
}

&svn_HEADER('Dump ' . &svn_REPO());

print '<table width="100%">'
    ,  '<tr><th colspan="3" align="center" style="font-size: 16pt;">Download a dump of repository "' , &svn_REPO() , '"</th></tr>'
    ,  '<tr><td colspan="3">&nbsp;</td></tr>'
    ,  '<tr>'
    ,   '<td nowrap width="33%" align="left"><a class="linkbutton" href="?Insurrection=dump&amp;Dump=go&amp;Deltas=1">Dump in 1.1 format</a></td>'
    ,   '<td nowrap width="34%" align="center"><a class="linkbutton" href="?Insurrection=dump&amp;Dump=go&amp;Deltas=1">Dump in 1.0 format</a></td>'
    ,   '<td nowrap width="33%" align="right"><a class="linkbutton" href="/">Cancel</a></td>'
    ,  '</tr>'
    ,  '<tr><td colspan="3">&nbsp;</td></tr>'
    , '</table>';

print '<p>This is a first-cut functional dump interface.&nbsp; It is not final.&nbsp; '
    , 'Note that the 1.1 format can be much smaller than the 1.0 format dumps.</p>';

&svn_TRAILER('$Id$');

