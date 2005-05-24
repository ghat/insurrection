#!/usr/bin/perl
#
# $Id$
# Copyright 2004,2005 - Michael Sinz
#
# This script handles the display of a specific version
#
require 'admin.pl';

## First, lets see if we in good standing...
&checkAuthMode();

## Get the revision
my $rev = &getNumParam($cgi->param('r'));
$rev = 'HEAD' if (!defined $rev);

## Get the local document URL
my $docURL = &svn_URL();

## Lets see if we can find the mime type...
my $mimeget = $SVN_CMD . ' propget --non-interactive --no-auth-cache -r ' . $rev . ' svn:mime-type ' . $docURL;
my $mime = `$mimeget`;
chomp $mime;
$mime = 'text/plain' if ((!defined $mime) || ($mime eq ''));

## Now, lets build the correct command to run...
my $cmd = $SVN_CMD . ' cat --non-interactive --no-auth-cache -r ' . $rev . ' ' . $docURL;

print $cgi->header('-expires' => '+1d' ,
                   '-type' => $mime);

print `$cmd`;

