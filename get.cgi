#!/usr/bin/perl
#
# $Id$
# Copyright 2004,2005 - Michael Sinz
#
# This script handles the display of a specific version
#
require 'admin.pl';

## First, lets see if we are allowed to look here:
&checkAuthPath($cgi->path_info);

## Get the revision
my $rev = $cgi->param('r');
$rev = 'HEAD' if (!defined $rev);

## Get the real document info
my $docURL = &svn_URL($cgi->path_info);

## Lets see if we can find the mime type...
my $mimeget = $SVN_CMD . ' propget --non-interactive --no-auth-cache -r ' . $rev . ' svn:mime-type ' . $docURL;
my $mime = `$mimeget`;
chomp $mime;
$mime = 'text/plain' if ((!defined $mime) || ($mime eq ''));

## Now, lets build the correct command to run...
my $cmd = $SVN_CMD . ' cat --non-interactive --no-auth-cache -r ' . $rev . ' ' . $docURL;

print "Expires: Fri Dec 31 19:00:00 1999\n"
    , "Cache-Control: no-cache\n"
    , "Accept-Ranges: bytes\n"
    , "Content-type: $mime\n"
    , "\n"
    , `$cmd`;

