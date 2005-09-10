#!/usr/bin/perl
#
# $Id$
# Copyright 2004,2005 - Michael Sinz
#
# This script takes the index.html template and inserts some
# specific dynamic content into it.
#
# Note that we track the changes via Subversion itself - that
# is, the access file is in the Subversion repository
#
require 'admin.pl';

open INDEX,"<index.template" || die "Where is index.template?";
my $index = join('',<INDEX>);
close INDEX;

my $repoTable = &repositoryTable();

$index =~ s:<repos/>:$repoTable:sgeo;

if ($index =~ m:<about/>:)
{
   my $about = '';
   if (open ABOUT,"<about.template")
   {
      $about = join('',<ABOUT>);
      close ABOUT;
   }
   $index =~ s:<about/>:$about:sgeo;
}

&svn_HEADER($SVN_INDEX_TITLE);

print $index;

&svn_TRAILER('$Id$');

