#
# $Id$
# Copyright 2004,2005 - Michael Sinz
#
# These are the constants that define some of the subversion configuration
# within the system plus some common code that is best to be shared for
# the admin functions.
#
require 'common.pl';

## Where the password and access files live
## Note that we read/write these files and then check them
## into Subversion using the command line.  So where these
## live should be a Subversioned directory and should have
## full rights from the web server CGI user.
my $PasswordFile = '.htauth/passwords';
my $AccessFile = '.htauth/access';

## Access lock files to prevent race problems.  We just flock
## them during execution of writes to the files...
my $AccessFileLock = '.htauth/.lock-AccessFile';
my $PasswordFileLock = '.htauth/.lock-PasswordFile';

# Set up our CGI context and get some information
use CGI;
$cgi = new CGI;
$AuthUser = $cgi->remote_user;

## We use file locks to protect the changes to our control files
use Fcntl ':flock'; # import LOCK_* constants

## We export these hashes for playing around with.
%groupComments; ## Comments for groups
%groupUsers;    ## The group users
%groupAdmins;   ## The group admin users
%userPasswords; ## The password file
$accessVersion; ## The version of the access file
$passwdVersion; ## The version of the password file


##############################################################################
#
# A simple is-member function that returns 1 (true) if the user is a member
# of the given group.
#
sub isMember($group,$user)
{
   my $group = shift;
   my $user = shift;

   foreach $t (@{$groupUsers{$group}})
   {
      return 1 if ($t eq $user);
   }

   return 0;
}

##############################################################################
#
# A simple is-admin function that returns 1 (true) if the user is an admin
# of the given group (and not a global admin)
#
sub isAdminMember($group,$user)
{
   my $group = shift;
   my $user = shift;

   foreach $t (@{$groupAdmins{$group}})
   {
      return 1 if ($t eq $user);
   }

   return 0;
}

##############################################################################
#
# A simple is-admin function that returns 1 (true) if the user is an admin
# of the given group or a global admin
#
sub isAdmin($group,$user)
{
   my $group = shift;
   my $user = shift;

   return 1 if (&isMember("Admin",$user));

   return &isAdminMember($group,$user);
}

##############################################################################
#
sub lockAccessFile()
{
   ## Lock the access file for the duration...
   open LOCK_AC,"<$AccessFileLock" or open LOCK_AC,">$AccessFileLock" or die "Could not open $AccessFileLock";
   flock(LOCK_AC,LOCK_EX);
}

##############################################################################
#
sub unlockAccessFile()
{
   ## Unlock the access file
   flock(LOCK_AC,LOCK_UN);
   close(LOCK_AC);
}

##############################################################################
#
# Access file loading and saving routines...
#
sub loadAccessFile()
{
   open DATA, "<$AccessFile" or die "Can not read file $AccessFile";
   my @lines = <DATA>;
   close DATA;
   chomp @lines;

   my $lastComment;
   my $section;
   foreach my $line (@lines)
   {
      chomp $line;

      ## Get the version of the file we are dealing with...
      if ($line =~ /^#.*\$Id\:\s*(.+?)\s*\$/)
      {
         $accessVersion = $1;
         chomp($accessVersion);
      }
      elsif ($line =~ /^#+\s*(.+)$/)
      {
         ## Comment lines are skipped but we remember them because we may need it
         $lastComment = $1;
      }
      elsif ($line =~ /^\[(.+?)\]$/)
      {
         $section = $1;
      }
      elsif ($line =~ /^\*/)
      {
         ## A wildcard entry - I guess we should skip it...
      }
      elsif ($line =~ /^@/)
      {
         ## A group rights definition - just skip it (we know what they are)
      }
      elsif (($line =~ /^Admin_(\S+)\s+=\s*(.*)$/) && ($section eq 'groups'))
      {
         ## Ahh, a group admin definition - now lets deal with it...
         my $group = $1;
         my @users = split(/,\s*/,$2);

         $groupComments{$group} = $lastComment if (!defined $groupUsers{$group});
         @{$groupAdmins{$group}} = @users;
      }
      elsif (($line =~ /^(\S+)\s+=\s*(.*)$/) && ($section eq 'groups'))
      {
         ## Ahh, a group definition - now lets deal with it...
         my $group = $1;
         my @users = split(/,\s*/,$2);

         $groupComments{$group} = $lastComment;
         @{$groupUsers{$group}} = @users;
      }
   }
}

##############################################################################
#
# and write the access file based on the hashmaps...
#
sub saveAccessFile($reason)
{
   my $reason = shift;

   if (defined $AuthUser)
   {
      open DATA, ">$AccessFile" or die "Can not write to file $AccessFile";
      flock(DATA,LOCK_EX);

      print DATA '#' , "\n"
               , '# Simple access control file for the Subversion server' , "\n"
               , '#' , "\n"
               , '# $' , 'Id: ' , $accessVersion , ' $' , "\n"
               , '#' , "\n"
               , '# This file is machine generated - do not hand edit!' , "\n"
               , '#' , "\n"
               , "\n"
               , '##' , "\n"
               , '## Give any valid user read-only rights if nothing else matches' , "\n"
               , '##' , "\n"
               , '[/]' , "\n"
               , '* = r' , "\n"
               , "\n"
               , '##' , "\n"
               , '## Define the access groups' , "\n"
               , '##' , "\n"
               , '[groups]' , "\n";

      foreach my $group (sort keys %groupUsers)
      {
         print DATA "\n"
                  , '## ' , $groupComments{$group} , "\n"
                  , $group , " = " , join(', ',sort @{$groupUsers{$group}}) , "\n";
      }

      print DATA "\n"
               , '##' , "\n"
               , '## Administrative groups - used for the CGI management' , "\n"
               , '##' , "\n";

      foreach my $group (sort keys %groupAdmins)
      {
         print DATA "\n"
                  , '## ' , $groupComments{$group} , "\n" if (!defined $groupUsers{$group});
         print DATA "Admin_" , $group , " = " , join(', ',sort @{$groupAdmins{$group}}) , "\n";
      }

      print DATA "\n"
               , '##' , "\n"
               , '## Define the repository access rights' , "\n"
               , '##' , "\n"
               , '' , "\n";

      foreach my $group (sort keys %groupUsers)
      {
         if ($group ne 'Admin')
         {
            print DATA "\n"
                     , "[$group:/]\n"
                     , '@' , $group , " = rw\n";
            print DATA '@Admin_' , $group , " = rw\n" if (defined $groupAdmins{$group});
         }
      }

      flock(DATA,LOCK_UN);
      close DATA;

      system($SVN_CMD,'commit','--username',$AuthUser,'-m',$reason,$AccessFile);
   }
}

##############################################################################
#
sub lockPasswordFile()
{
   ## Lock the password file for the duration...
   open LOCK_PW,"<$PasswordFileLock" or open LOCK_PW,">$PasswordFileLock" or die "Could not open $PasswordFileLock";
   flock(LOCK_PW,LOCK_EX);
}

##############################################################################
#
sub unlockPasswordFile()
{
   ## Lock the password file for the duration...
   flock(LOCK_PW,LOCK_UN);
   close(LOCK_PW);
}

##############################################################################
#
# Load the password file
#
sub loadPasswordFile()
{
   open DATA, "<$PasswordFile" or die "Can not read file $PasswordFile";
   while (<DATA>)
   {
      my $line = $_;
      chomp $line;

      ## Get the version of the file we are dealing with...
      if ($line =~ /^#.*\$Id\:\s*(.+?)\s*\$/)
      {
         $passwdVersion = $1;
         chomp($passwdVersion);
      }
      $line =~ s/#.*//;  ## Remove comments...
      my ($user,$pass,$junk) = split(/:/,$line,3);
      $userPasswords{$user} = $pass if (defined $pass);
   }
   close DATA;
}

##############################################################################
#
# Save the password file
#
sub savePasswordFile($reason)
{
   my $reason = shift;

   if (defined $AuthUser)
   {
      open DATA, ">$PasswordFile" or die "Can not write file $PasswordFile";
      flock(DATA,LOCK_EX);

      ## Our version tag marker...
      ## Note the need to separate the $ from the Id: otherwise the
      ## string would get replaced by our own version...
      print DATA "#\n"
               , "# The password file for Subversion and Apache/.htaccess\n"
               , "#\n"
               , '# $' , 'Id: ' , $passwdVersion , ' $' , "\n"
               , "#\n"
               , "# This is a computer managed file - do not hand edit!\n"
               , "#\n";

      foreach my $user (sort keys %userPasswords)
      {
         print DATA $user , ':' , $userPasswords{$user} , "\n";
      }

      flock(DATA,LOCK_UN);
      close DATA;

      system($SVN_CMD,'commit','--username',$AuthUser,'-m',$reason,$PasswordFile);
   }
}

return 1;
