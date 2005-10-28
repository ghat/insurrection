#!/usr/bin/perl
#
# $Id$
# Copyright 2004,2005 - Michael Sinz
#
# This script handles the saving of log message updates
#
require 'admin.pl';

my $msg = $cgi->param('newLog');
my $rev = getNumParam($cgi->param('rev'));

if ((defined $msg) && (defined $rev))
{
   ## For now we only support full repository management.  I plan to add
   ## sub-path management later
   my $repo = &svn_REPO();
   my $group = $repo . ':/';

   ## Must have read-write access...
   if (&typeMember($group,$AuthUser) > 1)
   {
      if (&isRevpropChange($repo))
      {
         ## Now try to do the work...
         my $localURL = &svn_URL();

         my $logUser = '';
         ## Ok, if the user is an administrator for the repository
         ## the user has the right to update the log entry of any
         ## revision...
         if (&isAdminMember($group,$AuthUser))
         {
            $logUser = $AuthUser;
         }
         else
         {
            ## If the user is not a repository admin then the
            ## user only has rights to update his own log
            ## entries in the repository
            my $cmd = $SVN_CMD . ' --no-auth-cache --non-interactive propget svn:author --revprop -r ' . $rev . ' ' . $localURL;
            $logUser = `$cmd`;
            chomp $logUser;
         }

         ## Only if you are the original log author...
         ## Or you are an admin for the given repository repository
         if ($logUser eq $AuthUser)
         {
            ## Next, if all is ok, set the property

            ## svn propset svn:log --revprop -r <n> <newLog> <url>
            print "Status: 200 Saved log message\n\n";

            ## Note that any output will be payload to the
            ## result...
            system($SVN_CMD,'-q','--no-auth-cache','--non-interactive',
                            'propset','svn:log','--revprop',
                            '-r',$rev,$msg,$localURL);
         }
         else
         {
            print "Status: 403 Only the original author may update the log entry\n";
         }
      }
      else
      {
         print "Status: 403 Log message update disabled\n";
      }
   }
   else
   {
      ## Fail due to rights...
      print "Status: 403 Log message update forbidden\n";
   }
}
else
{
   print "Status: 403 Protocol error\n";
}

