#!/usr/bin/perl
#
# $Id$
# Copyright 2004,2005 - Michael Sinz
#
# This script handles the broken XSLT browsers
# by having them load the XML directly.
#
require 'admin.pl';

## Get the real document info
my $pathInfo = $cgi->path_info;
my ($repo,$repo_path) = ($pathInfo =~ m|^(/[^/]+)(.*?)$|);
$repo_path = '/' if (!($repo_path =~ m|^/|));

## Print our standard header...   (Note the 0-minute expires!)
&svn_HEADER($repo_path,'+0m');

print '<img style="display: none;" id="closedImage" src="' , &svn_IconPath('closed') , '"/>'
    , '<img style="display: none;" id="openedImage" src="' , &svn_IconPath('opened') , '"/>'
    , '<img style="display: none;" id="dirImage" src="' , &svn_IconPath('dir') , '"/>'
    , '<img style="display: none;" id="fileImage" src="' , &svn_IconPath('file') , '"/>'
    , '<img style="display: none;" id="infoImage" src="' , &svn_IconPath('info') , '"/>'
    , '<img style="display: none;" id="blankImage" src="' , &svn_IconPath('blank') , '"/>';

print '<table border="0" cellpadding="0" cellspacing="0" width="100%">';

print '<tr class="updirrow">'
    ,  '<td colspan="4">'
    ,   '<a href=".." title="Go to parent directory">'
    ,    '<div class="updir">'
    ,     '<img src="' , &svn_IconPath('dir') , '" class="svnentryicon" align="middle">.. (Parent Directory)</div>'
    ,    '</a>'
    ,   '</td>'
    ,  '</tr>' if ($repo_path ne '/');

print  '<tr class="pathrow">'
    ,   '<td class="foldspace">'
    ,    '<img title="Expand directory" src="' , &svn_IconPath('closed') , '" id="/" onclick="loadDir(this)" class="dirarrow" align="middle"/>'
    ,   '</td>'
    ,   '<td class="path" width="99%">'
    ,    '<img src="' , &svn_IconPath('dir') , '" class="svnentryicon" align="middle"/>'
    ,    &svn_XML_Escape($repo_path)
    ,   '</td>'
    ,   '<td class="showlog">'
    ,    '<a href="?Insurrection=rss" title="RSS Feed of activity in this directory">'
    ,     '<img src="' , &svn_IconPath('rss') , '" alt="RSS Feed of activity in this directory" align="middle"/>'
    ,    '</a>'
    ,   '</td>'
    ,   '<td class="showlog">'
    ,    '<a href="?Insurrection=log" title="Show revision history for this directory">'
    ,     '<img src="' , &svn_IconPath('info') , '" alt="Show revision history for this directory" align="middle"/>'
    ,    '</a>'
    ,   '</td>'
    ,  '</tr>'
    ,  '<tr id="./_" style="display: none;">'
    ,   '<td><img src="' , &svn_IconPath('blank') , '"/></td>'
    ,   '<td id="./" colspan="3"></td>'
    ,  '</tr>'
    , '</table>';

print '<script language="JavaScript" type="text/javascript">'
    ,  'setTimeout(\'loadDir(document.getElementById("/"));\',100);'
    , '</script>';

&svn_TRAILER('$Id$');

