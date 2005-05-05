#
# $Id$
# Copyright 2004,2005 - Michael Sinz
#
# This is some common code that all of the Perl code
# needs.  Note that this includes the default configuration
# file such that only this code needs to know to include it.
require 'insurrection.pl';

# These are the constants that define some of the subversion configuration
# within the system plus some common code that is best to be shared for
# the admin functions.

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

## We use file locks to protect the changes to our control files
use Fcntl ':flock'; # import LOCK_* constants

## We export these hashes for playing around with.
%groupComments; ## Comments for groups
%groupUsers;    ## The group's users
%usersGroup;    ## The user's groups (a pivot just to make life eaier)
%groupAdmins;   ## The group admin users
%userPasswords; ## The password file
%userCreators;  ## The users who "created" this user
$accessVersion; ## The version of the access file
$passwdVersion; ## The version of the password file

# Set up our CGI context and get some information
use CGI;
$cgi = new CGI;
$AuthUser = $cgi->remote_user;

## Read the insurrection.xsl file for configuration information.
## The configuration is within the XSL file due to problems with
## certain browsers not supporting the XPath document() function.
my $insurrection_xml = '';
if (open(INSURRECTION,'<insurrection.xsl'))
{
   $insurrection_xml = join('',<INSURRECTION>);
   close(INSURRECTION);
}

## Get the blank icon path (we always need it)
my $blankIcon = &svn_IconPath('blank');

##
## Get the path of a given icon/graphic file
sub svn_IconPath($name)
{
   my $name = shift;
   my $result = '';
   $name .= 'icon-path';

   ## Figure out what the blank icon path is...
   if ($insurrection_xml =~ m|<xsl:template name="$name">([^<]*?)</xsl:template>|s)
   {
      $result = $1;
   }

   return $result;
}

##
## This function does the XML escaping for the '&', '<', '>', and '"'
## characters.  The first 3 are absolutely required and the last one
## enables putting the string within quoted parameters.
sub svn_XML_Escape($str)
{
   my $str = shift;

   $str =~ s/&/&amp;/sg;
   $str =~ s/</&lt;/sg;
   $str =~ s/>/&gt;/sg;
   $str =~ s/"/&quot;/sg;

   return $str;
}

##
## This function just does the %xx escaping of a string
## for use within URLs.  Even though it is so small, it
## is easier to maintain in one place rather than have
## it all over the place.
sub svn_URL_Escape($path)
{
   my $path = shift;

   ## Modify our path to escape some characters into URL form...
   $path =~ s|([^-.A-Za-z0-9/_])|sprintf("%%%02X",ord($1))|seg;

   return $path;
}

##
## This function takes a repository path from the URL
## and makes it into a local file:// URL.  It also
## makes sure that external ".." operations are not
## allowed to reach outside of the repository.
sub svn_URL($path)
{
   my $path = shift;

   if (defined $path)
   {
      ## Prevent ugly hacks from getting into my pathinfo...
      ## (The only one I care about is the '..')
      $path =~ s:(\.\./)|(/\.\.)|(^\.\.$)::g;

      ## Get rid of trailing '/'
      $path =~ s:/+$::;

      ## Fix up/escape as needed...
      $path = &svn_URL_Escape($path);

      ## Now, prepend the base and file:// URL construct
      $path = 'file://' . $SVN_BASE . $path;
   }

   return $path;
}

##
## This function takes a repository path from the URL
## and returns the local repository name information
sub svn_REPO($path)
{
   my $path = shift;

   if (defined $path)
   {
      ## Prevent ugly hacks from getting into my pathinfo...
      ## (The only one I care about is the '..')
      $path =~ s:(\.\./)|(/\.\.)|(^\.\.$)::g;

      ## Note that only the first element is used, so
      ## get rid of anything after the first element.
      $path =~ s:^/([^/]+).*$:$1:;
   }

   return $path;
}

##
## This function takes a repository path from the URL
## and returns the relative path from within the repository
sub svn_RPATH($path)
{
   my $path = shift;

   if (defined $path)
   {
      ## Prevent ugly hacks from getting into my pathinfo...
      ## (The only one I care about is the '..')
      $path =~ s:(\.\./)|(/\.\.)|(^\.\.$)::g;

      ## Get rid of trailing '/'
      $path =~ s:/+$::;

      ## Note that only the first element is used, so
      ## get rid of anything after the first element.
      if ($path =~ m:^/[^/]+(/.*)$:)
      {
         $path = $1;
      }
      else
      {
         $path = '/';
      }
   }

   return $path;
}

##
## This put up the default header for every CGI generated HTML page
## Note that the expires parameter is optional and will default to
## a 1 day expire.
sub svn_HEADER($title,$expires)
{
   my $title = shift;
   my $expires = shift;

   ## Expires is optional and thus we default it to 1 day if not given.
   $expires = '+1d' if (!defined $expires);

   my ($header) = ($insurrection_xml =~ m|<xsl:template name="header">(.*?)</xsl:template>|s);
   my ($banner) = ($insurrection_xml =~ m|<xsl:template name="banner">(.*?)</xsl:template>|s);

   print $cgi->header('-expires' => $expires ,
                      '-type' => 'text/html');

   print '<!doctype HTML PUBLIC "-//W2C//DTD HTML 4.01 Transitional//EN">' , "\n"
       , "<!-- Insurrection Web Tools for Subversion          -->\n"
       , "<!-- Copyright (c) 2004,2005 - Michael Sinz         -->\n"
       , "<!-- http://www.sinz.org/Michael.Sinz/Insurrection/ -->\n"
       , '<html>'
       ,  '<head>'
       ,   '<title>' , $title , '</title>'
       ,   $header
       ,  '</head>' , "\n"
       ,  '<body>'
       ,   '<table id="pagetable" cellpadding="0" cellspacing="0">'
       ,    '<tr>'
       ,     '<td id="top-left"><img src="' , $blankIcon , '"/></td>'
       ,     '<td id="top"><img src="' , $blankIcon , '"/></td>'
       ,     '<td id="top-right"><img src="' , $blankIcon , '"/></td>'
       ,    '</tr>'
       ,    '<tr>'
       ,     '<td id="left"><img src="' , $blankIcon , '"/></td>'
       ,     '<td id="content">'
       ,      $banner
       ,      '<div class="svn">' , "\n";
}

##
## This put up the default tail for all of the pages that use
## the svn_HEADER() function above.
sub svn_TRAILER($version)
{
   my $version = shift;

   ## Use the version of this file if there was no version passed.
   $version = '$Id$' if (!defined $version);

   print      '</div><div class="footer">' , $version;
   print      '&nbsp;&nbsp;--&nbsp;&nbsp;'
       ,      'You are logged on as: <b>' , $AuthUser , '</b>' if (defined $AuthUser);
   print      '</div>'
       ,     '</td>'
       ,     '<td id="right"><img src="' , $blankIcon , '"/></td>'
       ,    '</tr>'
       ,    '<tr>'
       ,     '<td id="bottom-left"><img src="' , $blankIcon , '"/></td>'
       ,     '<td id="bottom"><img src="' , $blankIcon , '"/></td>'
       ,     '<td id="bottom-right"><img src="' , $blankIcon , '"/></td>'
       ,    '</tr>'
       ,   '</table>'
       ,  '</body>'
       , '</html>';
}

##
## This function returns only the number part of the
## parameter.  We use this to filter incoming parameters
## to only include numbers (when needed)
sub getNumParam($param)
{
   my $result;
   my $param = shift;
   if ($param =~ m/(\d+)/)
   {
      $result = $1;
   }

   return $result;
}

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

      &svn_TRAILER('$Id$');
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
            $groupComments{$section} = $lastComment;
            %{$groupUsers{$section}} = %empty;
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
               , '# Simple access control file for the Insurrection server' , "\n"
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

      system($SVN_CMD,'commit','--non-interactive','--no-auth-cache','--username',$AuthUser,'-m',$reason,$AccessFile);
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
      my @creators = split(/:/,$line);
      my $user = shift @creators;
      my $pass = shift @creators;
      if (defined $pass)
      {
         $userPasswords{$user} = $pass;
         @{$userCreators{$user}} = @creators;
      }
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
         print DATA $user , ':' , $userPasswords{$user};
         print DATA ':' , join(':',@{$userCreators{$user}}) if (@{$userCreators{$user}} > 0);
         print DATA "\n";
      }

      flock(DATA,LOCK_UN);
      close DATA;

      system($SVN_CMD,'commit','--non-interactive','--no-auth-cache','--username',$AuthUser,'-m',$reason,$PasswordFile);
   }
}

##############################################################################
#
# Build and return an HTML table that contains the repositories that the
# given user has access to via some mechanism.
#
# Note, if no authenticated user, the anonymous user access will be used.
#
sub repositoryTable()
{
   my $user = '*';
   $user = $AuthUser if (defined $AuthUser);

   my $result = '';

   ## Check if we have loaded the admin stuff yet...
   &loadAccessFile() if (!defined $groupUsers);

   ## For the list of repositories and their sizes, we want
   ## to include the anonymous access repositories...
   %tlist = (%{$usersGroup{$user}},%{$usersGroup{'*'}});

   ## If the user is admin, get all groups.
   %tlist = %groupComments if (&isAdminMember('Admin',$AuthUser));

   @accessGroups = sort keys %tlist;
   if (@accessGroups > 0)
   {
      my $rssIcon = &svn_IconPath('rss');

      ## Get the sizes of all of the repositories...
      my %rSize;
      ## Only if the directory exists do we even try this...
      if (-d $SVN_BASE)
      {
         foreach my $line (split(/\n/,`cd $SVN_BASE ; du -s *`))
         {
            my ($size,$repo) = ($line =~ /^(\d+)\s+(\S.*)$/);
            $rSize{$repo} = $size;
         }
      }

      $result .= '<table class="accessinfo" cellspacing="0"><tr><th>Repository</th><th>Size</th><th>Description</th></tr>';

      my $totalSize = 0;

      foreach my $group (@accessGroups)
      {
         my $comments = $groupComments{$group};
         $group =~ s/(^[^:]+):.*$/$1/;
         my $size = $rSize{$group};
         if (defined $size)
         {
            $size += 0; ## Make sure that the size is a number...
            $totalSize += $size;

            ## Cute trick to get comas into the number...
            while ($size =~ s/(\d+)(\d\d\d)/$1,$2/) {}

            $result .= '<tr>'
                     .  '<td><a href="' . $SVN_REPOSITORIES_URL . $group . '/">' . $group . '</a></td>'
                     .  '<td align="right">' . $size . 'k</td>'
                     .  '<td>'
                     .   '<a href="' . $SVN_REPOSITORIES_URL . $group . '/?Insurrection=rss">'
                     .    '<img src="' . $rssIcon . '" alt="RSS Feed" border="0" style="padding-left: 2px;" align="right"/>'
                     .   '</a>'
                     .   $comments
                     .  '</td>'
                     . '</tr>';
         }
      }
      if ($totalSize > 0)
      {
         ## Cute trick to get comas into the number...
         while ($totalSize =~ s/(\d+)(\d\d\d)/$1,$2/) {}
         $result .= '<tr class="accessinfototal">'
                  .  '<td><b>Total:</b></td>'
                  .  '<td align="right">' . $totalSize . 'k</td>'
                  .  '<th>&nbsp;</th>'
                  . '</tr>';
      }
      $result .= "</table>";
   }

   return $result;
}


return 1;
