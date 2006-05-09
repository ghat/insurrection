#!/usr/bin/perl
#
# $Id$
# Copyright 2004,2005 - Michael Sinz
#
# This script handles the management of the web/svn access
# groups and adding/deleting users.
#
# Note that we track the changes via Subversion itself - that
# is, the access file is in the Subversion repository
#
require 'admin.pl';

use CGI;

## Load up the password file such that we can get the user list
&loadPasswordFile();

## First, lets read in the access file - We happen to need this
## just to get the status on this specific user...
&loadAccessFile();

## Since we check the admin status a number of times, do it once here...
my $isAdmin = &isAdminMember('Admin',$AuthUser);

## We have moved this to be the system management CGI and thus
## only full system admins have access... (even thought the code still
## supports all forms of access rights.  That will get fixed as we
## continue on.)
if (!$isAdmin)
{
   print $cgi->redirect('-location' => $SVN_URL_PATH,
                        '-status' => '302 Invalid path');
}

## Print our standard header...   (Note the 0-minute expires!)
&svn_HEADER('System Administration','+0m');

print '<center>'
    , '<div class="admin-title">'
    ,  'System&nbsp;Administration'
    , '</div>';

my $reloadForm = '<center><a href="?' . time . '">Reload System Administration Form</a></center>';

if (defined $cgi->param('NewRepository'))
{
   my $newRepo = $cgi->param('NewRepository');
   if (($newRepo =~ m/^[a-zA-Z][-_.a-zA-Z0-9]+$/) &&
      (length($newRepo) > 2) &&
      (length($newRepo) < 32))
   {
      &lockAccessFile();
      &loadAccessFile();

      my $group = "$newRepo:/";
      if (defined $groupUsers{$group})
      {
         print &startBoldFrame('Repository already exists: "' . &svn_XML_Escape($newRepo) . '"')
             , '<h2>Repository name already exists</h2>'
             , &endBoldFrame();
      }
      else
      {
         print &startInnerFrame('Creating new repository "' . &svn_XML_Escape($newRepo) . '"') , '<pre>';

         ## Note that by default, new repositories have the system administrator
         ## as a R/W user.  The system administrator may wish to add a repository
         ## administrator to the repository at some point.  That would be done
         ## using the normal management tools and not part of the creation process.
         my %initialUsers;
         $initialUsers{$AuthUser} = 'rw';
         $groupComments{$group} = 'Newly created repository <i>(Please edit this description)</i>';
         %{$groupUsers{$group}} = %initialUsers;

         #####################################################################
         ##
         ## This is where we create a new repository for the system.  Note
         ## that new repository structure is defined here.  If different
         ## structure is needed, this would be where you would need to change.
         ##
         ## Note that all of the initial structure work is
         ## Now, actually create the repository...
         print "Creating repository...\n";
         system($SVNADMIN_CMD,'create','--fs-type','fsfs',"$SVN_BASE/$newRepo");

         ## Now set up the default layout the way I want by checking out the
         ## repository into a temp directory and then adding the structure
         my $tmpdir = "/tmp/newRepo-$^T";
         mkdir($tmpdir);
         system($SVN_CMD,'checkout','--non-interactive','--no-auth-cache','file://' . $SVN_BASE . '/' . &svn_URL_Escape($newRepo),"$tmpdir/.");

         ## Build the trunk/branches/tags/releases directory structure
         system('mkdir',"$tmpdir/trunk","$tmpdir/branches","$tmpdir/tags","$tmpdir/releases");
         system($SVN_CMD,'add',"$tmpdir/trunk","$tmpdir/branches","$tmpdir/tags","$tmpdir/releases");

         ## Build the initial .svn_index file...
         if (open(TMP,">$tmpdir/.svn_index"))
         {
            print TMP '<!-- $' , 'Id$ -->' , "\n"
                    , "<h2>Repository: " , &svn_XML_Escape($newRepo) , "</h2>\n";
            close(TMP);
            system($SVN_CMD,'add',"$tmpdir/.svn_index");
            system($SVN_CMD,'propset','svn:eol-style','native',"$tmpdir/.svn_index");
            system($SVN_CMD,'propset','svn:keywords','Id',"$tmpdir/.svn_index");
         }

         ## We do a quick commit of this layout before setting up the hooks
         ## and access rights to ensure that all of this is in place before
         ## the repository is public.  Note also that the administrative
         ## user account that created the repository will be used as the
         ## user who did the initial checkin.
         system($SVN_CMD,'commit','--non-interactive','--no-auth-cache','--username',$AuthUser,'-m','Initial repository creation and layout',"$tmpdir/.");

         ## Ok, lets get the hook defined by default
         &enableImmutableTags($newRepo);

         ## Set up the initial bandwidth and disk space limits files
         ## (Just so that the defaults are written to the repository limit files)
         &repoBandwidthLimit($newRepo);   ## Use this to get/write the default
         &repoSizeLimit($newRepo);        ## Use this to get/write the default

         ## Clean up the temp directory we used to make this happen
         system('rm','-rf',$tmpdir);

         ## Save the changes to the access control file
         &saveAccessFile("manage.cgi: Created new repository:\n\n\t$newRepo");
         &loadAccessFile();
         ##
         ## The repository is now created with the initial access rights
         ## and comment.
         ##
         #####################################################################


         print '</pre>' , &endInnerFrame();
      }

      &unlockAccessFile();
   }
   else
   {
      print &startBoldFrame('Invalid repository name: "' . &svn_XML_Escape($newRepo) . '"')
          , '<h2>Invalid name for new repository</h2>'
          , &endBoldFrame();
   }
}


##############################################################################
### System repository administration form
print &startTableFrame(undef,'Repository&nbsp;',undef
                            ,'Size&nbsp;/&nbsp;&nbsp;Limit',undef
                            ,'Bandwidth&nbsp;/&nbsp;&nbsp;Limit',undef
                            ,'Description',undef
                            );

foreach my $group (sort keys %groupUsers)
{
   if ($group =~ m'^([^:]+):/$'o)
   {
      my $repo = $1;

      my $sizeLimit = &repoSizeLimit($repo);
      my $size = &repoSize($repo);

      my $usageLimit = &repoBandwidthLimit($repo);
      my $usage = &repoBandwidth($repo);

      my $bwLink = $SVN_URL_PATH . 'bandwidth.cgi/' . $repo . '/.raw-details./index.html';

      print &doTableFrameRow( '<a href="' . &svn_XML_Escape($SVN_URL_PATH . 'admin.cgi/' . $repo) . '/?Insurrection=admin" title="Administrate repository">' . &svn_XML_Escape($repo) . '</a>' , 'style="vertical-align: middle; padding-right: 4px; font-size: 12px;"'
                            , &niceNum($size) . 'k&nbsp;/&nbsp;&nbsp;' . &niceNum($sizeLimit) . 'k<br/>' . &gauge($size,$sizeLimit) , 'style="text-align: right; padding-left: 4px; padding-right: 4px;"'
                            , '<a href="' . &svn_XML_Escape($bwLink) . '" title="View usage details">' . &niceNum($usage) . '&nbsp;/&nbsp;&nbsp;' . &niceNum($usageLimit) . '<br/>' . &gauge($usage,$usageLimit) . '</a>' , 'style="text-align: right; padding-left: 4px; padding-right: 4px;"'
                            , $groupComments{$group} , undef
                            );
   }
}

print &doTableFrameRow( '' , undef
                      , '' , undef
                      , '<a href="' . &svn_XML_Escape($SVN_URL_PATH . 'bandwidth.cgi/--overhead--/.raw-details./index.html') . '" title="View usage details">System overhead</a>' , 'style="white-space: nowrap;"'
                      , 'Bandwidth details for system overhead' , undef
                      );
print &doTableFrameRow( '' , undef
                      , '' , undef
                      , '<a href="' . &svn_XML_Escape($SVN_URL_PATH . 'bandwidth.cgi/-Internal-/.raw-details./index.html') . '" title="View usage details">Internal overhead</a>' , 'style="white-space: nowrap;"'
                      , 'Internal bandwidth due to the proxy trick' , undef
                      );
print &doTableFrameRow( '' , undef
                      , '' , undef
                      , '<a href="' . &svn_XML_Escape($SVN_URL_PATH . 'bandwidth.cgi/--All--/.raw-details./index.html') . '" title="View usage details">All HTTP/HTTPS</a>' , 'style="white-space: nowrap;"'
                      , 'Usage details for all repositories on this server' , undef
                      );

print &endTableFrame();
### System repository administration form
##############################################################################

print '</center>';

## Since we split this, allow for the linking to the global user admin page...
print '<form action="manage_users.cgi"><input style="float: right;" type="submit" name="switch" value="Manage Users"/></form>';

##############################################################################
### Create repository form
print &startInnerFrame('Create a new repository')
    , '<form action="?" method="post">'
    , '<table border="0" cellpadding="1" cellspacing="3" style="margin: auto;">'
    , '<tr><td align="right">Repository name:</td><td align="left">&nbsp;<input type="text" size="16" maxlength="32" name="NewRepository"></td><td align="right">&nbsp;<input type="submit" name="Operation" value="Create"></td></tr>'
    , '</table>'
    , '</form>'
    , &endInnerFrame();
### Create repository form
##############################################################################


&svn_TRAILER('$Id$');

##############################################################################
#
# Make a number with "," at ever thousand (10^3)
#
sub niceNum($num)
{
   my $num = shift;
   while ($num =~ s/(\d+)(\d\d\d)/$1,$2/o) {}
   return $num;
}

