#!/usr/bin/perl
#
# $Id$
# Copyright 2004-2006 - Michael Sinz
#
# This script takes the index.html template and inserts some
# specific dynamic content into it.
#
# Note that we track the changes via Subversion itself - that
# is, the access file is in the Subversion repository
#
require 'admin.pl';

## Start out assuming a server-name based template
my $template = $ENV{'SERVER_NAME'} . '.template';

## Try opening by server name and then try the default...
$template = 'index.template' if (! -r $template);

open INDEX,"<$template" || die "Where is $template?";
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

