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
my $PasswordFile = $SVN_AUTH . '/passwords';
my $AccessFile = $SVN_AUTH . '/access';

## Access lock files to prevent race problems.  We just flock
## them during execution of writes to the files...
my $AccessFileLock = $SVN_AUTH . '/.lock-AccessFile';
my $PasswordFileLock = $SVN_AUTH . '/.lock-PasswordFile';

# Set up our CGI context and get some information
use CGI;
$cgi = new CGI;
$AuthUser = $cgi->remote_user;

## We use file locks to protect the changes to our control files
use Fcntl ':flock'; # import LOCK_* constants

## We export these hashes for playing around with.
%groupComments; ## Comments for groups
%groupUsers;    ## The group's users
%usersGroup;    ## The user's groups (a pivot just to make life eaier)
%groupAdmins;   ## The group admin users
%userPasswords; ## The password file
$accessVersion; ## The version of the access file
$passwdVersion; ## The version of the password file

##############################################################################
#
# This call will check if the given repository/path is available to the
# authorized user.
#
sub checkAuthPath($path)
{
   my $path = shift;

   ## Append a bit just in case it was not already there...
   $path .= '/';

   ## Check if we have loaded the admin stuff yet...
   &loadAccessFile() if (!defined $groupUsers);

   ## Just to make it easier, we add the ":" before the first slash
   ## in order to match the paths....

   ## NOTE!  Currently we just support repository root
   $path =~ s|^/?([^/]+)/.*$|$1:/|;

   ## Now lets check...
   return 1 if ((defined ${groupUsers{$path}}{$AuthUser}) || (defined ${groupUsers{$path}}{'*'}));

   if (!defined $AuthUser)
   {
      ## We are not authorized and we are not an authorized user, so
      ## redirect to the authorization version of this script
      my $target = $cgi->url;
      $target =~ s:^(.*)/([^/]+)$:$1/auth_$2:;

      ## just in case a double auth happened...
      $target =~ s:/auth_auth_:/auth_:;

      ## Now put the rest of the full URL together...
      $target .= substr($cgi->self_url,length($cgi->url));

      print $cgi->redirect($target);
   }
   else
   {
      print "Status: 403 Access Denied\n";

      &svn_HEADER('403 Access Denied');

      print '<h1>Access Denied</h1>'
          , '<p>You are not permitted access to the document '
          , 'requested.  You may have supplied the wrong '
          , 'credentials or selected the wrong URL</p>';

      &svn_TRAILER('$Id$',$AuthUser);
   }
   exit 0;
}

##############################################################################
#
# A simple member type function that returns:
#   0 if the user is not a member
#   1 if the user is read-only
#   2 if the user is read-write
#   3 if the user is admin of the group.
#
sub typeMember($group,$user)
{
   my $group = shift;
   my $user = shift;

   if (defined $groupUsers{$group})
   {
      my $type = ${groupUsers{$group}}{$user};
      if (defined $type)
      {
         return 1 if ($type eq 'r');

         ## Can only be admin if the access is r/w
         if ($type eq 'rw')
         {
            return 3 if (&isAdminMember($group,$user));
            return 2;
         }
      }
   }

   return 0;
}

##############################################################################
#
# A simple is-member function that returns 1 (true) if the user is a member
# of the given group.
#
sub isMember($group,$user)
{
   my $group = shift;
   my $user = shift;

   return 1 if (&typeMember($group,$user) != 0);
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

   ## Fix up the group name...
   if (!($group =~ /^Admin.*/))
   {
      $group = 'Admin_' . $group;
      if ($group =~ /(^[^:]+):/)
      {
         $group = $1;
      }
   }

   if (defined $groupAdmins{$group})
   {
      foreach $t (@{$groupAdmins{$group}})
      {
         return 1 if ($t eq $user);
      }
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

   return 1 if (&isAdminMember('Admin',$user));

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

   my %empty;
   %groupComments = %empty;
   %groupAdmins = %empty;
   %groupUsers = %empty;
   %usersGroup = %empty;

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
         if ($section ne 'groups')
         {
            $groupComments{$section} = $lastComment ;
            #delete $groupUsers{$section};
         }
      }
      elsif (($line =~ /^(Admin\S*)\s+=\s*(.*)$/) && ($section eq 'groups'))
      {
         ## Ahh, an admin definition - now lets deal with it...
         my $group = $1;
         my @users = split(/,\s*/,$2);

         @{$groupAdmins{$group}} = @users;
      }
      elsif (($line =~ /^(\S+)\s+=\s*(.*)$/) && ($section ne 'groups'))
      {
         my $user = $1;
         my $access = $2;

         if ($user =~ /^[^@]/)
         {
            ${$groupUsers{$section}}{$user} = $access;
            ${$usersGroup{$user}}{$section} = $access;
         }
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
               , '# This is a computer managed file - do not hand edit!' , "\n"
               , '#' , "\n"
               , "\n"
               , '#' , "\n"
               , '# Define the admin groups' , "\n"
               , '#' , "\n"
               , '[groups]' , "\n";

      foreach my $group (sort keys %groupAdmins)
      {
         print DATA $group , " = " , join(', ',sort @{$groupAdmins{$group}}) , "\n";
      }

      print DATA "\n"
               , '#' , "\n"
               , '# Define the repository access rights' , "\n"
               , '#' , "\n";


      foreach my $group (sort keys %groupUsers)
      {
         print DATA "\n"
                  , '# ' , $groupComments{$group} , "\n"
                  , "[$group]\n";

         my %users = %{$groupUsers{$group}};
         for my $user (sort keys %users)
         {
            my $access = $users{$user};
            print DATA "$user = $access\n";
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
