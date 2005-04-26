#!/usr/bin/perl
#
# $Id: index.cgi 215 2005-04-26 05:05:10Z svn $
# Copyright 2004,2005 - Michael Sinz
#
# This script takes the index.html template and inserts some
# specific dynamic content into it.
#
# Note that we track the changes via Subversion itself - that
# is, the access file is in the Subversion repository
#
require 'admin.pl';

use CGI;

open INDEX,"<index.template" || die "Where is index.template?";
my $index = join('',<INDEX>);
close INDEX;

my $repoTable = &repositoryTable($AuthUser);

$index =~ s:<repos/>:$repoTable:sge;

&svn_HEADER('MKSoft Demo Insurrection Server');

print $index;

&svn_TRAILER('$Id: index.cgi 215 2005-04-26 05:05:10Z svn $',$AuthUser);

