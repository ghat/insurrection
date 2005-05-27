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

## ###### HACK - HACK ###### HACK - HACK ###### HACK - HACK ######
##
## Yes, Virginia, we have a problem!  Apache's rewrite messes up
## some characters and we get all confused...  So, we try to
## fix it here before we call the CGI module.
##
## We happen to know at least one of the problems and since we
## always do the same thing in our system we know how to work
## around it (for the most part)
##
if ($ENV{'SERVER_PROTOCOL'} =~ m:^(.+)\s(HTTP/\d+\.\d+)$:)
{
   $ENV{'SERVER_PROTOCOL'} = $2;

   ## Note that we assume it was only one space...  If the
   ## first space is a double-space then we have a problem...
   $ENV{'REQUEST_URI'} .= ' ' . $1;
}

## We also know that we have a path parameter at the end
## (Always)
if ($ENV{'REQUEST_URI'} =~ m:&Path=(/.*)$:)
{
   ## Set up the PATH_INFO to match...
   $ENV{'PATH_INFO'} = $1;

   ## And now get the request URI to not have the Path argument
   $ENV{'REQUEST_URI'} =~ s:&Path=/.*$::;
}

## Finally, fix up the query string to match the request URI
($ENV{'QUERY_STRING'}) = ($ENV{'REQUEST_URI'} =~ m/\?(.*)$/);

##
## :END:
##
## ###### HACK - HACK ###### HACK - HACK ###### HACK - HACK ######

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

## Get the blank icon path and make a spacer (1x1) image
my $blank = '<img alt="" src="' . &svn_IconPath('blank') . '"/>';

##############################################################################
#
# Get the HTTP and server part of the URL.
# This should include:  http://server:port
# (no trailing slash)
#
sub svn_HTTP()
{
   if ($cgi->url =~ m|(https?://[^/]+)|)
   {
      return $1;
   }

   ## If we can not find the host, something bad happened!
   return 'http://svn.code-host.net';
}

##############################################################################
#
# Get the path of a given icon/graphic file
#
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

##############################################################################
#
# This function does the XML escaping for the '&', '<', '>', and '"'
# characters.  The first 3 are absolutely required and the last one
# enables putting the string within quoted parameters.
#
sub svn_XML_Escape($str)
{
   my $str = shift;

   $str =~ s/&/&amp;/sg;
   $str =~ s/</&lt;/sg;
   $str =~ s/>/&gt;/sg;
   $str =~ s/"/&quot;/sg;

   return $str;
}

##############################################################################
#
# This function just does the %xx escaping of a string
# for use within URLs.  Even though it is so small, it
# is easier to maintain in one place rather than have
# it all over the place.
#
sub svn_URL_Escape($path)
{
   my $path = shift;

   ## Modify our path to escape some characters into URL form...
   $path =~ s|([^-.A-Za-z0-9/_])|sprintf("%%%02X",ord($1))|seg;

   return $path;
}

##############################################################################
#
# This function takes a repository path from the URL
# and makes it into a local file:// URL.  It also
# makes sure that external ".." operations are not
# allowed to reach outside of the repository.
#
sub svn_URL()
{
   my $path = $cgi->path_info;

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

##############################################################################
#
# This function takes a repository path from the URL
# and returns the local repository name information
#
sub svn_REPO()
{
   my $path = $cgi->path_info;

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

##############################################################################
#
# This function takes a repository path from the URL
# and returns the relative path from within the repository
#
sub svn_RPATH()
{
   my $path = $cgi->path_info;

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

##############################################################################
#
# This put up the default header for every CGI generated HTML page
# Note that the
# Note that the expires parameter is optional and will default to
# a 1 day expire.
#
sub svn_HEADER($title,$expires,$doctype)
{
   my $title = shift;
   my $expires = shift;
   my $doctype = shift;

   ## If no doctype, set the good default...
   $doctype = '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">' if (!defined $doctype);

   ## Expires is optional and thus we default it to 1 day if not given.
   $expires = '+1d' if (!defined $expires);

   my ($header) = ($insurrection_xml =~ m|<xsl:template name="header">(.*?)</xsl:template>|s);
   my ($banner) = ($insurrection_xml =~ m|<xsl:template name="banner">(.*?)</xsl:template>|s);

   ## Darn HTML 4 does not let <link> tags be closed!  How annoying!
   $header =~ s|(<link\s[^>]*)/>|$1>|gs;

   print $cgi->header('-expires' => $expires ,
                      '-type' => 'text/html');

   print $doctype , "\n"
       , "<!-- Insurrection Web Tools for Subversion          -->\n"
       , "<!-- Copyright (c) 2004,2005 - Michael Sinz         -->\n"
       , "<!-- http://www.sinz.org/Michael.Sinz/Insurrection/ -->\n"
       , '<html>'
       ,  '<head>'
       ,   '<title>' , &svn_XML_Escape($title) , '</title>'
       ,   $header
       ,  '</head>' , "\n"
       ,  '<body>'
       ,   '<table id="pagetable" cellpadding="0" cellspacing="0">'
       ,    '<thead>'
       ,     '<tr>'
       ,      '<th id="top-left">' , $blank , '</th>'
       ,      '<th id="top">' , $blank , '</th>'
       ,      '<th id="top-right">' , $blank , '</th>'
       ,     '</tr>'
       ,    '</thead>'
       ,    '<tfoot>'
       ,     '<tr>'
       ,      '<th id="bottom-left">' , $blank , '</th>'
       ,      '<th id="bottom">' , $blank , '</th>'
       ,      '<th id="bottom-right">' , $blank , '</th>'
       ,     '</tr>'
       ,    '</tfoot>'
       ,    '<tbody>'
       ,     '<tr>'
       ,      '<th id="left">' , $blank , '</th>'
       ,      '<td id="content">'
       ,       $banner
       ,       '<div class="svn"><div id="localbanner"></div>' , "\n";
}

my $oldHTML = 0;

##############################################################################
#
# This does the header with an older doctype...
#
sub svn_HEADER_oldHTML($title,$expires)
{
   my $title = shift;
   my $expires = shift;

   ## Flag that we are not 4.01...
   $oldHTML = 1;

   ## We have &svn_HEADER_int as the function that does all
   ## of the work...  This just is here to give an old doctype
   &svn_HEADER($title,
               $expires,
               '<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">');
}

##############################################################################
#
# This put up the default tail for all of the pages that use
# the svn_HEADER() function above.
#
sub svn_TRAILER($version)
{
   my $version = shift;

   ## Use the version of this file if there was no version passed.
   $version = '$Id$' if (!defined $version);

   print       '</div>'
       ,       '<div class="footer">';
   print        '<a title="Valid HTML 4.01!" href="http://validator.w3.org/check?uri=referer">'
       ,         '<img style="margin-left: 1em;" align="right" border="0" src="/valid-html401.png" alt="Valid HTML 4.01!">'
       ,        '</a>' if (!$oldHTML);
   print        $version;
   print        '&nbsp;&nbsp;--&nbsp;&nbsp;'
       ,        'You are logged on as: <b>' , $AuthUser , '</b>' if (defined $AuthUser);
   print       '</div>'
       ,      '</td>'
       ,      '<th id="right">' , $blank , '</th>'
       ,     '</tr>'
       ,    '</tbody>'
       ,   '</table>'
       ,  '</body>'
       , '</html>';
}

##############################################################################
#
# This function returns only the number part of the
# parameter.  We use this to filter incoming parameters
# to only include numbers (when needed)
#
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
# Returns true if the browser is known to be broken with respect to XSLT.
# The rest of the code will then figure out what to do to address this.
#
# What a trick - to get the broken browsers to work.
#
# Note that the XSLT of Safari is almost working but
# not quite.  So it is listed here.
#
# Note that if someone expressly wants XML, the
# XMLHttp=1 attribute is needed.
#
# Note that we would like to have the real XSLT working
# as there are some things that are not available
# without it *and* the bandwidth and server load are
# much lower.  The good thing is that the top two
# browser technologies do work correctly enough to
# not need this hack.  That ends up covering 98% of
# all wed users.  (That is Mozilla/Firefox and IE)
#
sub isBrokenBrowser()
{
   return ((!defined $cgi->param('XMLHttp')) && ($cgi->user_agent =~ m/(Opera)|(Safari)|(Konqueror)/));
}

##############################################################################
#
# This call will check if the CGI was executed within the Insurrection proxy
# environment.  If not, it redirects into that environment.
#
sub checkAuthMode()
{
   ## Get the base CGI name such that we can double check the access...
   my ($type) = ($cgi->url =~ m|^.*/([^/]+)\.cgi$|);

   my $path = substr($cgi->path_info(),1);

   ## Lets check if this happened to come through the internal
   ## proxy request.  The reason this is important is that the
   ## mod_authz_svn will have already authenticated the request
   ## and now all we need to do is trust it.  In all other cases
   ## Note: This security can be broken if someone else puts in
   ## a proxy on the same server and sets it up just right...
   if ((($ENV{'REMOTE_ADDR'} eq $ENV{'SERVER_ADDR'})
      && ($ENV{'HTTP_HOST'} eq $ENV{'HTTP_X_FORWARDED_HOST'}))
      && (length($path) > 2)
      && (defined $cgi->param('Insurrection'))
      && ($cgi->param('Insurrection') eq $type))
   {
      return 1;
   }

   ## If we can not figure out what is to be done, we just punt...
   my $target = $SVN_URL_PATH;

   ## Ok, so how did we get here?  It was not via the proxy rules
   ## in the .htaccess file so we don't want it.  Lets redirect
   ## back through the proxy rule URL (if we can make it.)
   ## The goal here is to be sure that things are really as they
   ## should be.
   if ((defined $type) && (length($path) > 2))
   {
      ## Make sure we strip out any "old" Insurrection=xxx elements
      ## from the qwery string before we go adding a specific one...
      my $qstring = $ENV{'QUERY_STRING'};
      $qstring =~ s/Insurrection=((.*?&)|(.*$))//;
      $qstring = '&' . $qstring if (length($qstring) > 0);
      $target = $SVN_REPOSITORIES_URL . $path . '?Insurrection=' . $type . $qstring;
   }

   print $cgi->redirect('-location' => $target,
                        '-status' => '301 Moved Permanently');
   exit 0;
}

##############################################################################
#
# This checks that the access to the given repository is being done by an
# admin for that repository or the global admin.  If either fails, we just
# redirect to the main default page.
#
sub checkAdminMode()
{
   ## Now, lets check that we are a real admin for the repository
   return 1 if (&isAdmin(&svn_REPO(),$AuthUser));

   print $cgi->redirect('-location' => $SVN_URL_PATH,
                        '-status' => '302 Invalid path');
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

   ## Check if we have loaded the admin stuff yet...
   &loadAccessFile() if (!defined %groupUsers);

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

   ## Check if we have loaded the admin stuff yet...
   &loadAccessFile() if (!defined %groupAdmins);

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

   return 0 if (!defined $user);

   return 1 if (&isAdminMember('Admin',$user));

   if (defined $group)
   {
      return &isAdminMember($group,$user);
   }

   foreach $group (@accessGroups)
   {
      return 1 if (&isAdminMember($group,$user));
   }

   return 0;
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
   &loadAccessFile() if (!defined %groupUsers);

   ## Now, for each access type, build the correct table...
   $result .= &makeRepositoryTable(3) if (defined $AuthUser);
   $result .= &makeRepositoryTable(2) if (defined $AuthUser);
   $result .= &makeRepositoryTable(1);
   $result .= &makeRepositoryTable(0) if (defined $AuthUser);

   if ($result ne '')
   {
      $result = '<table class="accessinfo" cellspacing="0">' . $result . '</table>';
   }

   return $result;
}

## Store the sizes of the repositories in this "global" such that we only every
## get the du once, but only when we need it...
my %rSize;

##############################################################################
#
# This actually builds the table rows for the given access type and current
# user authentication.
#
sub makeRepositoryTable($type)
{
   my $type = shift;

   my $user = '*';
   $user = $AuthUser if (defined $AuthUser);

   my $result = '';

   my $isAdmin = &isAdminMember('Admin',$AuthUser);

   if (($type != 0) || $isAdmin)
   {
      my $totalSize = 0;
      my $totalCount = 0;
      my $rssIcon = &svn_IconPath('rss');

      foreach my $g (sort keys %groupComments)
      {
         my $utype = &typeMember($g,$user);
         my $atype = &typeMember($g,'*');
         $utype = $atype if ($atype > $utype);

         if ($utype == $type)
         {
            my $comments = $groupComments{$g};

            ## Add the table elements for the result...
            if ($result eq '')
            {
               $result .= '<tr><th>Repository</th>';

               if (($type == 3) || $isAdmin)
               {
                  $result .= '<th>Size</th><th width="99%">';
               }
               else
               {
                  $result .= '<th colspan="2" width="99%">';
               }

               if ($type == 3)
               {
                  $result .= '(Admin Access)';
               }
               elsif ($type == 2)
               {
                  $result .= '(Full Access)</th>';
               }
               elsif ($type == 1)
               {
                  $result .= '(Read-Only)';
               }
               else
               {
                  $result .= '(No Access)';
               }

               $result .= '</th></tr>';
            }

            ## Get the nice display name...
            my $group = $g;
            $group =~ s/(^[^:]+):.*$/$1/;

            $result .= '<tr>'
                     .  '<td><a title="Explore repository ' . $group . '" href="' . $SVN_REPOSITORIES_URL . $group . '/">' . $group . '</a></td>';

            ## Now, if we want the sizes...
            if (($type == 3) || $isAdmin)
            {
               ## Only do this once, and only when/if we need to.
               if (!defined $rSize{$group})
               {
                  foreach my $line (split(/\n/,`cd $SVN_BASE ; du -s *`))
                  {
                     my ($s,$r) = ($line =~ /^(\d+)\s+(\S.*)$/);
                     $rSize{$r} = $s;
                  }
               }

               my $size = $rSize{$group};
               $totalSize += $size;
               $totalCount++;

               ## Cute trick to get comas into the number...
               while ($size =~ s/(\d+)(\d\d\d)/$1,$2/) {}

               $result .=  '<td align="right">' . $size . 'k</td><td>';
            }
            else
            {
               $result .= '<td colspan="2" align="left">';
            }

            $result .=   '<a title="RSS Feed of activity in repository ' . $group . '" href="' . $SVN_REPOSITORIES_URL . $group . '/?Insurrection=rss">'
                     .    '<img src="' . $rssIcon . '" alt="RSS Feed of activity in repository ' . $group . '" border="0" style="padding-left: 2px;" align="right"/>'
                     .   '</a>';

            $result .=   '<a title="Download a dump of repository ' . $group . '" href="' . $SVN_REPOSITORIES_URL . $group . '/?Insurrection=dump">'
                     .    '<img src="' . &svn_IconPath('dump') . '" alt="Download a dump of repository ' . $group . '" border="0" style="padding-left: 2px;" align="right"/>'
                     .   '</a>'
                     .   '<a title="Bandwidth usage of repository ' . $group . '" href="' . $SVN_REPOSITORIES_URL . $group . '/?Insurrection=bandwidth">'
                     .    '<img src="' . &svn_IconPath('usage') . '" alt="Bandwidth usage of repository ' . $group . '" border="0" style="padding-left: 2px;" align="right"/>'
                     .   '</a>' if ($type == 3);

            $result .=   $comments
                     .  '</td>'
                     . '</tr>';
         }
      }

      ## We don't want individual totals if we are admin...
      $totalSize = 0 if ($isAdmin);

      ## Build the overall total...
      if ($type == 0)
      {
         foreach my $r (keys %rSize)
         {
            $totalSize += $rSize{$r};
            $totalCount++;
         }
      }

      if (($totalSize > 0) && ($totalCount > 1))
      {
         ## Cute trick to get comas into the number...
         while ($totalSize =~ s/(\d+)(\d\d\d)/$1,$2/) {}
         $result .= '<tr class="accessinfototal">'
                  .  '<td>Total:</td>'
                  .  '<td>' . $totalSize . 'k</td>'
                  .  '<td>&nbsp;</td>'
                  . '</tr>';
      }
   }

   return $result;
}

##############################################################################
#
# This returns an HTML table element that shows a horizontal gauge that
# represents the "fullness" of the data.  The $fill is the amount in the
# "container" and the $limit is what a full container can hold.
# The $title is optional but would be used to build a more descriptive
# title tag for the table.  The default is just to show the percentage)
#
sub gauge($fill,$limit,$title)
{
   my $fill = shift;
   my $limit = shift;
   my $title = shift;

   my $raw = $fill * 100 / $limit;

   ## The $filled value is what we use to
   ## build the image widths.
   my $filled = int($raw + 0.5);

   ## Make sure we are not 0% or 100% unless we
   ## really are completely empty or full.
   ## This is only for the image sizing, not
   ## the actual number.
   $filled = 1 if (($filled == 0) && ($fill > 0));
   $filled = 99 if (($filled == 100) && ($fill < $limit));

   ## Cute trick to get comas into the number...
   while ($fill =~ s/(\d+)(\d\d\d)/$1,$2/) {}
   while ($limit =~ s/(\d+)(\d\d\d)/$1,$2/) {}

   $title .= ' : ' if (defined $title);
   $title = '' if (!defined $title);
   $title = &svn_XML_Escape(sprintf('%s%.2f%%',$title,$raw));

   my $result = '';

   $result .= '<div style="margin: 0; padding: 0; text-align: left; border: 0;">';
   $result .= '<table class="gauge" title="' . $title . '" cellpadding="0" cellspacing="0" border="0"><tr>';

   ## If we are over the "100%" then put it into critical display...
   if ($raw > 100)
   {
      $result .= '<td class="gaugestartcritical">' . $blank . '</td>';
      $result .= '<td class="gaugecritical" width="100%">' . $blank . '</td>';
      $result .= '<td class="gaugeendcritical">' . $blank . '</td>';
   }
   else
   {
      if ($filled > 0)
      {
         $result .= '<td class="gaugestartfilled">' . $blank . '</td>';
         if ($filled > 1)
         {
            $result .= '<td class="gaugefilled" width="' . $filled . '%">' . $blank . '</td>';
         }
      }
      else
      {
         $result .= '<td class="gaugestartempty">' . $blank . '</td>';
      }

      if ($filled < 100)
      {
         if ($filled < 99)
         {
            $result .= '<td class="gaugeempty" width="' . (100 - $filled) . '%">' . $blank . '</td>';
         }
         $result .= '<td class="gaugeendempty">' . $blank . '</td>';
      }
      else
      {
         $result .= '<td class="gaugeendfilled">' . $blank . '</td>';
      }
   }

   $result .= '</tr></table>';
   $result .= '</div>';

   return $result;
}

return 1;

