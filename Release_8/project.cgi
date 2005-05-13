#!/usr/bin/perl
#
# $Id$
# Copyright 2004,2005 - Michael Sinz
#
# This script takes the project.html template and inserts some
# specific dynamic content into it.
#
# Note that we track the changes via Subversion itself - that
# is, the access file is in the Subversion repository
#
require 'admin.pl';

open INDEX,"<project.template" || die "Where is project.template?";
my $index = join('',<INDEX>);
close INDEX;

$index =~ s|http://server:port|$SVN_URL|gs;

&svn_HEADER('MKSoft Insurrection Project');

print $index;

&svn_TRAILER('$Id$');

