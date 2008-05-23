#
# $Id$
# Copyright 2004-2006 - Michael Sinz
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
our %groupComments; ## Comments for groups
our %groupUsers;    ## The group's users
our %usersGroup;    ## The user's groups (a pivot just to make life eaier)
our %groupAdmins;   ## The group admin users
our %userPasswords; ## The passwords (encrypted)
our %userDates;     ## The date of the last password change
our $accessVersion; ## The version of the access file
our $passwdVersion; ## The version of the password file

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
if (defined $ENV{'SERVER_PROTOCOL'})
{
   if ($ENV{'SERVER_PROTOCOL'} =~ m:^(.+)\s(HTTP/\d+\.\d+)$:o)
   {
      $ENV{'SERVER_PROTOCOL'} = $2;

      ## Note that we assume it was only one space...  If the
      ## first space is a double-space then we have a problem...
      $ENV{'REQUEST_URI'} .= ' ' . $1;
   }

   ## We also know that we have a path parameter at the end
   ## (Always)
   if ($ENV{'REQUEST_URI'} =~ m:&Path=(/.*)$:o)
   {
      ## Set up the PATH_INFO to match...
      $ENV{'PATH_INFO'} = $1;

      ## And now get the request URI to not have the Path argument
      $ENV{'REQUEST_URI'} =~ s:&Path=/.*$::o;
   }

   ## Finally, fix up the query string to match the request URI
   ($ENV{'QUERY_STRING'}) = ($ENV{'REQUEST_URI'} =~ m/\?(.*)$/o);
}
##
## :END:
##
## ###### HACK - HACK ###### HACK - HACK ###### HACK - HACK ######

# Set up our CGI context and get some information
use CGI;
our $cgi = new CGI;
our $AuthUser = $cgi->remote_user;

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
   if ($cgi->url =~ m|(https?://[^/]+)|o)
   {
      my $tmp = $1;
      ## Check if we are to use HTTPS
      ## This is needed in cases where we have been internally
      ## proxied for supporting the unified URL syntax.  This
      ## way we can tell if the link came externally from https
      ## (the rewrite/proxy rule makes sure this is set.)
      $tmp =~ s|^http:|https:|o if ($cgi->param('HTTPS') eq 'on');
      return $tmp;
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

   $str =~ s/&/&amp;/sgo;
   $str =~ s/</&lt;/sgo;
   $str =~ s/>/&gt;/sgo;
   $str =~ s/"/&quot;/sgo;

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
   $path =~ s|([^-.A-Za-z0-9/_])|sprintf("%%%02X",ord($1))|sego;

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
      $path =~ s:(\.\./)|(/\.\.)|(^\.\.$)::go;

      ## Get rid of trailing '/'
      $path =~ s:/+$::o;

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
      $path =~ s:(\.\./)|(/\.\.)|(^\.\.$)::go;

      ## Note that only the first element is used, so
      ## get rid of anything after the first element.
      $path =~ s:^/([^/]+).*$:$1:o;
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
      $path =~ s:(\.\./)|(/\.\.)|(^\.\.$)::go;

      ## Get rid of trailing '/'
      $path =~ s:/+$::o;

      ## Note that only the first element is used, so
      ## get rid of anything after the first element.
      if ($path =~ m:^/[^/]+(/.*)$:o)
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
   $doctype = '<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">' if (!defined $doctype);

   ## Expires is optional and thus we default it to 1 day if not given.
   $expires = '+1d' if (!defined $expires);

   my ($header) = ($insurrection_xml =~ m|<xsl:template name="header">(.*?)</xsl:template>|so);
   my ($banner) = ($insurrection_xml =~ m|<xsl:template name="banner">(.*?)</xsl:template>|so);

   ## Darn HTML 4 does not let <link> tags be closed!  How annoying!
   $header =~ s|(<link\s[^>]*)/>|$1>|gso;

   print $cgi->header('-expires' => $expires ,
                      '-type' => 'text/html; charset=utf-8');

   print $doctype , "\n"
       , "<!-- Insurrection Web Tools for Subversion          -->\n"
       , "<!-- Copyright (c) 2004-2006 - Michael Sinz         -->\n"
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
       ,      '<th id="top"></th>'
       ,      '<th id="top-right"></th>'
       ,     '</tr>'
       ,    '</thead>'
       ,    '<tfoot>'
       ,     '<tr>'
       ,      '<th id="bottom-left"></th>'
       ,      '<th id="bottom"></th>'
       ,      '<th id="bottom-right">' , $blank , '</th>'
       ,     '</tr>'
       ,    '</tfoot>'
       ,    '<tbody>'
       ,     '<tr>'
       ,      '<th id="left"></th>'
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

   ## We have &svn_HEADER as the function that does all
   ## of the work...  This just is here to give a non-valid HTML tag...
   &svn_HEADER($title,
               $expires);
}

##############################################################################
#
# This returns the content that needs to be in a page to show the no-HTTPS
# warning.  Note that you should insert this into the page where you want
# the warning.  It will make a display with the style for element class
# NoHTTPS
#
# Note that if the argument is undefined then no check will be included
# This makes it easy to have the check optional based on, say, the $AuthUser
# variable.
#
sub httpsCheckJS($flag)
{
   return '' if (!defined $_[0]);
   return('<script type="text/javascript" language="JavaScript" src="' . $SVN_URL_PATH . 'https-check.js"></script>');
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

   ## Now, lets just use the version information a title attribute of the footer

   print       '</div>'
       ,       '<div class="footer" title="' , &svn_XML_Escape($version) , '">';
   print        '<a title="Valid HTML 4.01!" href="http://validator.w3.org/check?uri=referer">'
       ,         '<img src="' , &svn_IconPath('html') , '" alt="Valid HTML 4.01!"/>'
       ,        '</a>' if (!$oldHTML);
   print        'Anonymous' if (!defined $AuthUser);
   print        'You are logged on as: <b>' , $AuthUser , '</b>' if (defined $AuthUser);
   print       '</div>'
       ,      '</td>'
       ,      '<th id="right"></th>'
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
   if ($param =~ m/(\d+)/o)
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
# X-Insurrection-JS header will be set to "true"
#
# Note that we would like to have the real XSLT working
# as there are some things that are not available
# without it *and* the bandwidth and server load are
# much lower.  The good thing is that the top two
# browser technologies do work correctly enough to
# not need this hack.  That ends up covering 98% of
# all wed users.  (That is Mozilla/Firefox and IE)
# Safari will/does work correctly as of webkit 420+
# so also detect that.
# 
# Also, now that I have an iPod Touch, I found out that the
# "Safari" browser in it does not do XML/XSLT at all so
# we need to make it "bad"
#
# Note test filter downwards - thus the "OK" or 0 return
# is done as early as possible.
#
sub isBrokenBrowser()
{
   ## If the user agent does not match this pattern we
   ## assume that it is a correctly working browser
   return 0 if (!($cgi->user_agent =~ m/(Opera)|(Safari)|(Konqueror)|(Blazer)/o));

   ## If the request is from the JavaScript code then
   ## it is for sure not broken behavior...
   return 0 if (defined $ENV{'HTTP_X_INSURRECTION_JS'});

   ## Safari has some extra checking since as of webkit 420+
   ## it seems to handle XML/XSLT correctly...  (But not on
   ## the iPhone or iPod Touch!)
   if ($cgi->user_agent =~ m:AppleWebKit/(\d+\.\d+):o)
   {
      ## Darn "full Safari" in iPod/iPhone is not really...
      return 1 if ($cgi->user_agent =~ m/iPod/);

      my $ver = $1 + 0;
      return 0 if ($ver >= 420);
   }

   ## Well, if we get here it must be a broken browser
   return 1;
}

##############################################################################
#
# This call will check if the CGI was executed within the Insurrection proxy
# environment.  If not, it redirects into that environment.
#
sub checkAuthMode()
{
   ## Get the base CGI name such that we can double check the access...
   my ($type) = ($cgi->url =~ m|^.*/([^/]+)\.cgi$|o);

   my $path = $cgi->path_info();
   if ((defined $path) && (length($path) > 1))
   {
      $path = substr($cgi->path_info(),1);

      ## Lets check if this happened to come through the internal
      ## proxy request.  The reason this is important is that the
      ## mod_authz_svn will have already authenticated the request
      ## and now all we need to do is trust it.  In all other cases
      ## Note: This security can be broken if someone else puts in
      ## a proxy on the same server and sets it up just right...
      ## (Note, to handle HTTP_X_FORWARDED_HOST correctly we need
      ## deal with multiple entries - we assume that the last entry
      ## is that added by the current server - which is what we
      ## next to check if it is "self-referential" and thus already
      ## has cleared the main security checks)
      if ((($ENV{'REMOTE_ADDR'} eq $ENV{'SERVER_ADDR'})
         && ($ENV{'HTTP_X_FORWARDED_HOST'} =~ m/^(.*, )*\Q$ENV{'HTTP_HOST'}\E$/))
         && (length($path) > 2)
         && (defined $cgi->param('Insurrection'))
         && ($cgi->param('Insurrection') eq $type))
      {
         return 1;
      }
   }
   else
   {
      $path = '';
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
      $qstring =~ s/Insurrection=((.*?&)|(.*$))//o;
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
      my $type = ${$groupUsers{$group}}{$user};
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

   ## Only if we are given a user name does this even matter...
   if (defined $user)
   {
      ## Fix up the group name...
      if (!($group =~ m/^Admin.*/o))
      {
         $group = 'Admin_' . $group;
         if ($group =~ m/(^[^:]+):/o)
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
   my @lines;
   if (open(DATA,"<$AccessFile"))
   {
      @lines = <DATA>;
      close DATA;
      chomp @lines;
   }

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
      if ($line =~ m/^#.*\$Id\:\s*(.+?)\s*\$/o)
      {
         $accessVersion = $1;
         chomp($accessVersion);
      }
      elsif ($line =~ m/^#+\s*(.+)$/o)
      {
         ## Comment lines are skipped but we remember them because we may need it
         $lastComment = $1;
      }
      elsif ($line =~ m/^\[(.+?)\]$/o)
      {
         $section = $1;
         if ($section ne 'groups')
         {
            $groupComments{$section} = $lastComment;
            %{$groupUsers{$section}} = %empty;
         }
      }
      elsif (($line =~ m/^(Admin\S*)\s*=\s*(.*?)$/o) && ($section eq 'groups'))
      {
         ## Ahh, an admin definition - now lets deal with it...
         my $group = $1;
         my @users = split(/,\s*/,$2);

         @{$groupAdmins{$group}} = @users;
      }
      elsif (($line =~ m/^(\S+)\s*=\s*(.*?)$/o) && ($section ne 'groups'))
      {
         my $user = $1;
         my $access = $2;

         if ($user =~ m/^[^@]/o)
         {
            ${$groupUsers{$section}}{$user} = $access;
            ${$usersGroup{$user}}{$section} = $access;
         }
      }
   }

   ## Special case - if we hace no lines in the access file
   ## or it does not exist, just put all repositories as * = r
   if (@lines == 0)
   {
      if (opendir(REPOS,$SVN_BASE))
      {
         foreach my $repo (grep(/^[a-zA-Z][-_.a-zA-Z0-9]+$/,readdir(REPOS)))
         {
            ## Check if there is a hooks directory
            if (opendir(TESTHOOK,"$SVN_BASE/$repo/hooks"))
            {
               closedir(TESTHOOK);

               ## Yes, so this looks like a repository
               my $section = "$repo:/";
               $groupComments{$section} = "Repository for $repo";
               %{$groupUsers{$section}} = %empty;
               ${$groupUsers{$section}}{'*'} = 'r';
               ${$usersGroup{'*'}}{$section} = 'r';
            }
         }
         closedir(REPOS);
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
      system($SVN_CMD,'update','--non-interactive','--no-auth-cache',$AccessFile);
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
      if ($line =~ m/^#.*\$Id\:\s*(.+?)\s*\$/o)
      {
         $passwdVersion = $1;
         chomp($passwdVersion);
      }
      $line =~ s/#.*//o;  ## Remove comments...
      my @data = split(/:/,$line);
      my $user = shift @data;
      my $pass = shift @data;
      my $date = shift @data;
      $date = time if (!defined $date);
      if (defined $pass)
      {
         $userPasswords{$user} = $pass;
         $userDates{$user} = $date;
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
         print DATA $user , ':' , $userPasswords{$user} , ':' , $userDates{$user} , "\n";
      }

      flock(DATA,LOCK_UN);
      close DATA;

      system($SVN_CMD,'commit','--non-interactive','--no-auth-cache','--username',$AuthUser,'-m',$reason,$PasswordFile);
      system($SVN_CMD,'update','--non-interactive','--no-auth-cache',$PasswordFile);
   }
}

##############################################################################
#
# Generate a random password of up to 12 characters (upper/lower/numbers)
#
sub genPassword()
{
   my $result='';

   ## Seed the generator
   srand();

   ## Now, generate a password/verification word.
   for (my $i=0; $i<12; $i++)
   {
      ## We ask for more than just 62 numbers
      ## (which is the number of letters and digits)
      ## such that we can also generate passwords that
      ## have less characters...  (sneaky :-)
      my $p = int(rand(64));

      if ($p < 10)
      {
         $result .= chr($p + 48);
      }
      elsif ($p < 36)
      {
         $result .= chr($p - 10 + 65);
      }
      elsif ($p < 62)
      {
         $result .= chr($p - 10 - 26 + 65 + 32);
      }
   }

   return $result;
}

##############################################################################
#
# Make an EMail address from a user name if the user name is not already in
# an EMail form...
#
sub emailAddress($user)
{
   my $user = shift;
   $user .= $EMAIL_DOMAIN if (!($user =~ /@/o));
   return $user;
}

## Some constants we need for the time routines
my @Months = ( 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December' );
my @Days = ( 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday' );

##############################################################################
#
# Convert a time value into a nice string
#
sub niceTime($time)
{
   my @modtime=gmtime shift;
   $modtime[5] += 1900 if ($modtime[5] < 1900);

   my $result=sprintf('%s, %s %d, %04d at %d:%02d GMT',
                      $Days[$modtime[6]],
                      $Months[$modtime[4]],
                      $modtime[3],
                      $modtime[5],
                      $modtime[2],
                      $modtime[1]);

   return $result;
}

##############################################################################
#
# Convert a time value into a HTTP header time string
#
sub webTime($time)
{
   my @modtime=gmtime shift;
   $modtime[5] += 1900 if ($modtime[5] < 1900);

   my $result = sprintf('%s, %02d %s %04d %02d:%02d:%02d GMT',
                        substr($Days[$modtime[6]],0,3),
                        $modtime[3],
                        substr($Months[$modtime[4]],0,3),
                        $modtime[5],
                        $modtime[2],
                        $modtime[1],
                        $modtime[0]);

   return $result;
}

## We need to be able to reverse a time value
use Time::Local 'timegm';

##############################################################################
#
# Convert the Subversion log date format into RFC822 format.
# Note that we use the Time::Local for this
#
sub timeFromISO($isodate)
{
   my $isodate = shift;
   my $result = 0;

   if ($isodate =~ m/(\d\d\d\d)-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)/o)
   {
      $result = timegm($6,$5,$4,$3,$2-1,$1);
   }

   return $result;
}

##############################################################################
#
# Convert the Subversion log date format into RFC822 format.
#
sub dateFormat($isodate)
{
   return &webTime(&timeFromISO(shift));
}

##############################################################################
#
# Start an inner frame with the given title string and optional extra attrs.
# After starting an inner frame, output your normal contents and then
# call endInnerFrame().  Frames can be nested.
#
sub startInnerFrame($title,$extra)
{
   my $title = shift;
   my $extra = shift;

   $extra = '' if (!defined $extra);

   return('<table class="innerframe" cellspacing="0" cellpadding="0" ' . $extra . '>'
         . '<thead>'
         .  '<tr>'
         .   '<td class="innerframe-top-left">' . $blank . '</td>'
         .   '<td class="innerframe-top">' . $title . '</td>'
         .   '<td class="innerframe-top-right"></td>'
         .  '</tr>'
         . '</thead>'
         . '<tfoot>'
         .  '<tr>'
         .   '<td class="innerframe-bottom-left"></td>'
         .   '<td class="innerframe-bottom"></td>'
         .   '<td class="innerframe-bottom-right">' . $blank . '</td>'
         .  '</tr>'
         . '</tfoot>'
         . '<tbody>'
         .  '<tr>'
         .   '<td class="innerframe-left"></td>'
         .   '<td class="innerframe">');
}

##############################################################################
#
# End an inner frame - this must be called for each startInnerFrame call.
# Frames can be nested.
#
sub endInnerFrame()
{
   return(   '</td>'
         .   '<td class="innerframe-right"></td>'
         .  '</tr>'
         . '</tbody>'
         .'</table>');
}

##############################################################################
#
# Start a bold frame with the given title string and optional extra attrs
# After starting an inner frame, output your normal contents and then
# call endBoldFrame().
#
sub startBoldFrame($title,$extra)
{
   my $title = shift;
   my $extra = shift;

   $extra = '' if (!defined $extra);

   return('<table class="boldframe" cellspacing="0" cellpadding="0" ' . $extra . '>'
         . '<thead>'
         .  '<tr>'
         .   '<td class="boldframe-top-left">' . $blank . '</td>'
         .   '<td class="boldframe-top">' . $title . '</td>'
         .   '<td class="boldframe-top-right"></td>'
         .  '</tr>'
         . '</thead>'
         . '<tfoot>'
         .  '<tr>'
         .   '<td class="boldframe-bottom-left"></td>'
         .   '<td class="boldframe-bottom"></td>'
         .   '<td class="boldframe-bottom-right">' . $blank . '</td>'
         .  '</tr>'
         . '</tfoot>'
         . '<tbody>'
         .  '<tr>'
         .   '<td class="boldframe-left"></td>'
         .   '<td class="boldframe">');
}

##############################################################################
#
# End an inner frame - this must be called for each startBoldFrame call.
# Frames can be nested.
#
sub endBoldFrame()
{
   return(   '</td>'
         .   '<td class="boldframe-right"></td>'
         .  '</tr>'
         . '</tbody>'
         .'</table>');
}

## Keep track of our table frame row number for alternating backgrounds...
my $tableFrameRow;

##############################################################################
#
# Start a framed table with the given title strings and optional extra attrs
# Each row you output needs to be prefixed with a startTableFrameRow
# and end with a endTableFrameRow.
#
sub startTableFrame($extra,$title,$titleExtra,$title,$titleExtra,...)
{
   my $extra = shift;
   $extra = '' if (!defined $extra);

   my @titles = @_;
   @titles = ('&nbsp;',undef) if (@titles < 1);

   my $result = '<table class="tableframe" cellspacing="0" cellpadding="0"' . $extra . '>'
              .  '<thead><tr><td class="tableframe-top-left">' . $blank . '</td>';

   for (my $i=0; $i < @titles; $i += 2)
   {
      $result .= '<td class="tableframe-top"';
      $result .= ' ' . $titles[$i+1] if (defined $titles[$i+1]);
      $result .= '>' . $titles[$i] . '</td>';
      $result .= '<td class="tableframe-top-div">' . $blank . '</td>' if (($i + 2) < @titles);
   }

   $result .= '<td class="tableframe-top-right"></td></tr></thead>'
            . '<tfoot><tr><td class="tableframe-bottom-left"></td>';

   for (my $i=0; $i < @titles; $i += 2)
   {
      $result .= '<td class="tableframe-bottom"></td>';
      $result .= '<td class="tableframe-bottom-div"></td>' if (($i + 2) < @titles);
   }

   $result .= '<td class="tableframe-bottom-right">' . $blank . '</td></tr></tfoot>'
            . '<tbody>';

   ## Set the row number to 0...
   $tableFrameRow = 0;

   return $result;
}

##############################################################################
#
# Start a table frame row - you only need to output your <td>...</td> data
# This also makes the rows alternate in colour (subtle grey variation)
# The needed <tr> constructs have been done for you...
#
# If the "plain" flag is "true" then the row will be plain (no odd/even)
#
sub startTableFrameRow($plain)
{
   if (shift)
   {
      return('<tr class="tableframe-row-last"><td class="tableframe-left"></td>');
   }
   else
   {
      if ($tableFrameRow)
      {
         $tableFrameRow = 0;
         return('<tr class="tableframe-row-odd"><td class="tableframe-left"></td>');
      }
      else
      {
         $tableFrameRow = 1;
         return('<tr class="tableframe-row-even"><td class="tableframe-left"></td>');
      }
   }
}

##############################################################################
#
# End a table frame row - you only need to output your <td>...</td> data
# The needed </tr> constructs will be done for you
#
sub endTableFrameRow()
{
   return('<td class="tableframe-right"></td></tr>');
}

##############################################################################
#
# This does the actual work of making a table frame row based on the type of
# row and the data for the row.
#
sub doTableFrameRow1($plain,$cell,$cellExtra,$cell,$cellExtra,...)
{
   my $result = &startTableFrameRow(shift);

   my @cells = @_;

   for (my $i=0; $i < @cells; $i += 2)
   {
      $result .= '<td';
      $result .= ' ' . $cells[$i+1] if (defined $cells[$i+1]);
      $result .= '>' . $cells[$i] . '</td>';

      if (($i + 2) < @cells)
      {
         $result .= '<td class="tableframe-div"></td>';
      }
   }

   $result .= &endTableFrameRow();

   return $result;
}

##############################################################################
#
# This does the hard work of putting together a row of data for the table.
# Note that it automatically adds the cell tags and that column dividers.
#
sub doTableFrameRow($cell,$cellExtra,$cell,$cellExtra,...)
{
   return &doTableFrameRow1(0,@_);
}

##############################################################################
#
# This makes a table frame row that is "plain" which we use for the end of
# a sortable table for rows that we don't want sorted.  (Such as rows with
# buttons, etc)
#
sub doTableFrameLastRows($cell,$cellExtra,$cell,$cellExtra,...)
{
   return &doTableFrameRow1(1,@_);
}

##############################################################################
#
# End an inner table frame - this must be called for each startTableframe.
# Frames can be nested.
#
sub endTableFrame()
{
   return('</tbody></table>');
}

## This is used to flag the need for the login or password button
my $loginButton;

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

   $loginButton = '';
   if (!defined $AuthUser)
   {
      my $loginURL = 'auth_index.cgi';

      if ($HTTPS_LOGIN)
      {
         $loginURL = $cgi->url;
         $loginURL =~ s/^http:/https:/o;
      }

      $loginButton = '<a title="Login" href="' . $loginURL . '">'
                   .  '<img src="' . &svn_IconPath('login') . '" alt="Login" border="0" align="right"/>'
                   . '</a>';
   }
   else
   {
      $loginButton = '<a title="Change Password" href="password.cgi">'
                   .  '<img src="' . &svn_IconPath('password') . '" alt="Change Password" border="0" align="right"/>'
                   . '</a>';

      if (&isAdminMember('Admin',$AuthUser))
      {
         ## Compensate for the 90 pixel password button by making
         ## a lot of pixels of padding (2 + 44 + 44 = 90)
         $loginButton .= '<a title="System Administration" href="manage.cgi">'
                       .  '<img src="' . &svn_IconPath('admin') . '" alt="System Administration" border="0" align="left" style="padding-left: 2px; padding-right: 44px;"/>'
                       . '</a>';
      }
      else
      {
         ## Compensate for the 90 pixel password button...
         $loginButton .= '<img src="' . &svn_IconPath('blank') . '" alt="" border="0" align="left" width="90" height="1"/>';
      }
   }

   ## Check if we have loaded the admin stuff yet...
   &loadAccessFile() if (!defined %groupUsers);

   ## Now, for each access type, build the correct table...
   $result .= &makeRepositoryTable(3) if (defined $AuthUser);
   $result .= &makeRepositoryTable(2) if (defined $AuthUser);
   $result .= &makeRepositoryTable(1);
   $result .= &makeRepositoryTable(0) if (defined $AuthUser);

   ## Just in case, if the login button was not displayed
   ## because of no available repositories, put it up here...
   if ($loginButton ne '')
   {
      $result .= &startTableFrame('width="100%"',$loginButton . '&nbsp;',undef)
               . &endTableFrame();
   }

   return $result;
}

my @accessTypes = ('No Access','Read Only','Full Access','Admin Access');

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

   if (($type != 0) || &isAdminMember('Admin',$AuthUser))
   {
      my $rssIcon = &svn_IconPath('rss');
      my $atomIcon = &svn_IconPath('atom');

      foreach my $g (sort keys %groupComments)
      {
         my $utype = &typeMember($g,$user);
         my $atype = &typeMember($g,'*');
         $utype = $atype if ($atype > $utype);

         if ($utype == $type)
         {
            ## Add the table elements for the result...
            if ($result eq '')
            {
               ## Note that the width style is just to make the column as
               ## narrow as possible to fit the data.  We depend on the
               ## fact that columns will automatically expand due to content.
               $result = &startTableFrame('width="100%"'
                                         ,'Repository&nbsp;Name','style="width: 1px; padding-right: 4px; text-align:left; white-space: nowrap;"'
                                         ,$loginButton . '(' . $accessTypes[$type] . ')',undef);
               $loginButton = '';
            }

            ## Get the nice display name...
            my $group = $g;
            $group =~ s/(^[^:]+):.*$/$1/o;

            my $repolink = $group;
            my $descript = '';

            if ($type > 0)
            {
               $repolink = '<a title="Explore repository ' . $group . '" href="' . $SVN_REPOSITORIES_URL . $group . '/">' . $group . '</a>';

               $descript .= '<a title="RSS Feed of activity in repository ' . $group . '" href="' . $SVN_REPOSITORIES_URL . $group . '/?Insurrection=rss">'
                          .  '<img src="' . $rssIcon . '" alt="RSS Feed of activity in repository ' . $group . '" border="0" style="padding-left: 2px;" align="right"/>'
                          . '</a>'
                          . '<a title="Atom Feed of activity in repository ' . $group . '" href="' . $SVN_REPOSITORIES_URL . $group . '/?Insurrection=atom">'
                          .  '<img src="' . $atomIcon . '" alt="Atom Feed of activity in repository ' . $group . '" border="0" style="padding-left: 2px;" align="right"/>'
                          . '</a>';

               $descript .= '<a title="Administrate repository ' . $group . '" href="' . $SVN_REPOSITORIES_URL . $group . '/?Insurrection=admin">'
                          .  '<img src="' . &svn_IconPath('admin') . '" alt="Administrate repository ' . $group . '" border="0" style="padding-left: 2px;" align="right"/>'
                          . '</a>' if ($type == 3);
            }

            $descript .= $groupComments{$g};

            $result .= &doTableFrameRow($repolink,'nowrap',$descript,undef);
         }
      }
   }

   if ($result ne '')
   {
      $result .= &endTableFrame();
   }

   return $result;
}

##############################################################################
#
# Return the size of a given repository in "k" bytes.  Note that it will
# return 0 if there is no known size.
#
sub repoSize($repo)
{
   my $repo = shift;

   ## The repository directory on the local disk...
   my $repoDir = $SVN_BASE . '/' . $repo;

   my $diskUsage = 0;
   if (`du -s $repoDir` =~ m/^\s*(\d+)\s+/so)
   {
      $diskUsage = $1
   }

   return $diskUsage;
}

##############################################################################
#
# Return the size limit of a given repository in "k" bytes.  Note that it will
# 250 meg if there is no known size.
#
sub repoSizeLimit($repo)
{
   my $repo = shift;

   ## The repository directory on the local disk...
   my $repoDir = $SVN_BASE . '/' . $repo;

   my $diskLimit = 250 * 1024;

   ## See if the repository has a specific disk limit
   if (open(DISKLIMIT,'<' . $repoDir . '/disk.limit'))
   {
      my $tmp = <DISKLIMIT>;
      chomp $tmp;
      close DISKLIMIT;

      $diskLimit = 0 + $tmp if ((defined $tmp) && ($tmp =~ m/^\d+$/o));
   }
   elsif (open(DISKLIMIT,'>' . $repoDir . '/disk.limit'))
   {
      print DISKLIMIT $diskLimit;
      close DISKLIMIT;
   }

   return $diskLimit;
}

##############################################################################
#
# Return the bandwidth used so far this month.  Note that on the first of
# the month this returns last month's numbers.
#
sub repoBandwidth($repo)
{
   my $repo = shift;

   ## The repository usage directory on the local disk...
   my $repoDir = $SVN_LOGS . '/usage-history/' . $repo;

   my @tm = gmtime time;
   my $file = sprintf('usage-%04d-%02d.db',$tm[5] + 1900,$tm[4] + 1);

   my $usage = 0;
   if (open(DB,"<$repoDir/$file"))
   {
      my $t = <DB>;
      close(DB);
      if ($t =~ m/\D*?(\d+)\D*/)
      {
         $usage = $1;
      }
   }

   return $usage;
}

##############################################################################
#
# Return the bandwidth limit of a given repository in bytes per month.
# Note that it will return 1gig if there is no known limit.
#
sub repoBandwidthLimit($repo)
{
   my $repo = shift;

   ## The repository directory on the local disk...
   my $repoDir = $SVN_BASE . '/' . $repo;

   ## The bandwidth limit default is 1gig (1024 * 1024 * 1024 bytes)
   my $bandwidthLimit = 1024 * 1024 * 1024;

   ## See if the repository has a specific bandwidth limit
   if (open(BWLIMIT,'<' . $repoDir . '/bandwidth.limit'))
   {
      my $tmp = <BWLIMIT>;
      chomp $tmp;
      close BWLIMIT;

      $bandwidthLimit = 0 + $tmp if ((defined $tmp) && ($tmp =~ m/^\d+$/o));
   }
   elsif (open(BWLIMIT,'>' . $repoDir . '/bandwidth.limit'))
   {
      print BWLIMIT $bandwidthLimit;
      close BWLIMIT;
   }

   return $bandwidthLimit;
}

##############################################################################
#
# Return true if the Immutable Tags pre-commit hook is enabled
#
sub isImmutableTags($repo)
{
   my $repo = shift;

   my $result = 0;
   if (open(TST,"<$SVN_BASE/$repo/hooks/pre-commit"))
   {
      close(TST);
      $result = 1;
   }
   return $result;
}

##############################################################################
#
# Enable the Immutable Tags pre-commit hook for the repository
# Returns true if it changed the state of things
#
sub enableImmutableTags($repo)
{
   my $repo = shift;

   my $result = !&isImmutableTags($repo);
   if ($result)
   {
      ### Yuck - this makes sure that the pre-commit hook
      ### is set up from our authentication system.  Note
      ### that this depends on symlink.
      ### In the "windows" world, we would need to do
      ### something like copying the hook.  The problem
      ### with that is that it does not allow for simple
      ### centeralized management of the hook code.  Using
      ### the symlink lets me update the hook code in one
      ### place and have all of the repositories on the
      ### server use that new version.
      ### So, yes, this is not Windows server compatible.

      ### One could check for non-funtioning symlinks and
      ### switch to copy operations here...
      symlink('../../../authentication/pre-commit',"$SVN_BASE/$repo/hooks/pre-commit");
   }

   return $result;
}

##############################################################################
#
# Disable the Immutable Tags pre-commit hook for the repository
# Returns true if it changed the state of things
#
sub disableImmutableTags($repo)
{
   my $repo = shift;

   my $result = &isImmutableTags($repo);
   if ($result)
   {
      ### Just delete the hook to disable the immutability for tags/releases
      unlink("$SVN_BASE/$repo/hooks/pre-commit");
   }

   return $result;
}

##############################################################################
#
# Return true if the revprop change hook is enabled
#
sub isRevpropChange($repo)
{
   my $repo = shift;

   my $result = 0;
   if (open(TST,"<$SVN_BASE/$repo/hooks/pre-revprop-change"))
   {
      close(TST);
      $result = 1;
   }
   return $result;
}

##############################################################################
#
# Enable the revprop change hook for the repository (svn:log only)
# Returns true if it changed the state of things
#
sub enableRevpropChange($repo)
{
   my $repo = shift;

   my $result = !&isRevpropChange($repo);
   if ($result)
   {
      ### Yuck - this makes sure that the hook
      ### is set up from our authentication system.  Note
      ### that this depends on symlink.
      ### In the "windows" world, we would need to do
      ### something like copying the hook.  The problem
      ### with that is that it does not allow for simple
      ### centeralized management of the hook code.  Using
      ### the symlink lets me update the hook code in one
      ### place and have all of the repositories on the
      ### server use that new version.
      ### So, yes, this is not Windows server compatible.

      ### One could check for non-funtioning symlinks and
      ### switch to copy operations here...
      symlink('../../../authentication/pre-revprop-change',"$SVN_BASE/$repo/hooks/pre-revprop-change");
   }

   return $result;
}

##############################################################################
#
# Disable the revprop change hook for the repository
# Returns true if it changed the state of things
#
sub disableRevpropChange($repo)
{
   my $repo = shift;

   my $result = &isRevpropChange($repo);
   if ($result)
   {
      ### Just delete the hook to disable svn:log revprop changing
      unlink("$SVN_BASE/$repo/hooks/pre-revprop-change");
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
   while ($fill =~ s/(\d+)(\d\d\d)/$1,$2/o) {}
   while ($limit =~ s/(\d+)(\d\d\d)/$1,$2/o) {}

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

1;

