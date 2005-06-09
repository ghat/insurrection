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

## Now, start figuring out what happened...
if (defined $cgi->param('update'))
{
   ## We saved a new set of user credentials.  Note that we never loose the
   ## $AuthUser from the list of system administrators
   $cgi->param(&makeID($AuthUser),1);

   ## Lock the file and load it...
   &lockAccessFile();
   &loadAccessFile();

   print &startInnerFrame('Action log: Update system administrators');

   ## Check that we have not crossed paths with someone
   if ($accessVersion ne $cgi->param('version'))
   {
      print '<h2 style="color: red;">Concurrent modification attempted<br/>Please recheck data and submit again</h2>'
   }
   else
   {
      my %newAdmins;
      my $actions = '';

      foreach my $user (sort keys %userPasswords)
      {
         if ($cgi->param(&makeID($user)) == 1)
         {
            $newAdmins{$user} = 1;
            if (!&isAdminMember('Admin',$user))
            {
               $actions .= "\tAdded user $user as a System Administrator\n";
            }
         }
         elsif (&isAdminMember('Admin',$user))
         {
            $actions .= "\tRemoved user $user as a System Administrator\n";
         }
      }

      if (length($actions) > 0)
      {
         @{$groupAdmins{'Admin'}} = keys %newAdmins;

         print "<pre>$actions</pre>";
         &saveAccessFile("manage.cgi: Updated System Administrator User List\n\n$actions");
         &loadAccessFile();
      }
   }

   &unlockAccessFile();

   print $reloadForm;
   print &endInnerFrame();
}
elsif (defined $cgi->param('DeleteUser'))
{
   my $user = $cgi->param('DeleteUser');

   ## Don't let the admin delete himself!
   if ((defined $userPasswords{$user}) && ($user ne $AuthUser))
   {
      print &startBoldFrame('Delete user "<b>' . $user . '</b>"')
          , '<form method="post" action="?">'
          ,  '<table width="100%"><tr>'
          ,   '<td align="left"><input type="submit" name="Delete" value="Yes!"/></td>'
          ,   '<td align="right"><input type="submit" name="Cancel" value="No"/></td>'
          ,  '</table>'
          ,  '<input type="hidden" name="DelUser" value="' , &svn_XML_Escape($user) , '"/>'
          , '</form>'
          , &endBoldFrame();
   }
}
elsif ((defined $cgi->param('DelUser')) && (defined $cgi->param('Delete')))
{
   my $user = $cgi->param('DelUser');

   print &startInnerFrame('Action log: Deleting user');

   ## Lock the password file...
   &lockPasswordFile();
   &loadPasswordFile();

   ## Don't let the admin delete himself!
   if ((defined $userPasswords{$user}) && ($user ne $AuthUser))
   {
      delete $userPasswords{$user};
      print "<pre>\tDeleted user $user\n</pre>";

      &savePasswordFile('manage.cgi: Deleted user ' . $user);
      &loadPasswordFile();
   }

   &unlockPasswordFile();

   print $reloadForm;
   print &endInnerFrame();
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

print &endTableFrame();
### System repository administration form
##############################################################################

##############################################################################
### User system admin administration form
print '<form method="post" action="">'
    , '<input type="hidden" name="version" value="' , &svn_XML_Escape($accessVersion) , '"/>'
    , &startTableFrame(undef,'User Name&nbsp;',undef
                            ,'Member of...',undef
                            ,'Last PW change:',undef
                            ,'System Administrator?',undef);

my @accessLevels = ('No','System Administrator');
my @months = ( "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" );

foreach my $user (sort keys %userPasswords)
{
   my $level = &isAdminMember('Admin',$user);

   my $access = '<select name="' . &makeID($user) . '" size="1">';
   for (my $i=0; $i < 2; $i++)
   {
      $access .= '<option value="' . $i . '"';
      $access .= ' selected' if ($i == $level);
      $access .= '>' . $accessLevels[$i] . '</option>';
   }
   $access .= '</select>';

   ## Get the number repositories the user has access to
   my $groups = scalar keys %{$usersGroup{$user}};

   ## Last password change
   my $lastChanged = '-never-';
   if ($userDates{$user} > 0)
   {
      my @tm = gmtime $userDates{$user};
      $lastChanged = sprintf('%s %02d, %04d',$months[$tm[4]],$tm[3], $tm[5] + 1900);
   }

   print &doTableFrameRow('<a href="?DeleteUser=' . &svn_XML_Escape($user) . '" title="Delete user">' . &svn_XML_Escape($user) . '</a>', 'nowrap style="vertical-align: middle; padding-right: 4px; font-size: 12px;"'
                         ,$groups . ' group' . (($groups == 1) ? '':'s'), 'nowrap style="text-align: right; padding-left: 4px; padding-right: 4px;"'
                         ,$lastChanged, 'nowrap style="text-align: right; padding-left: 4px; padding-right: 4px;"'
                         ,$access, 'style="padding-left: 4px; text-align: left;"'
                         );
}

print &doTableFrameRow('<input type="reset"/>','align="left"'
                      ,'&nbsp;',undef
                      ,'&nbsp;',undef
                      ,'<input type="submit" name="update" value="Save Changes"/>','align="right"'
                      );

print &endTableFrame()
    , '</form>';
### User system admin administration form
##############################################################################

print '</center>';

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

##############################################################################
#
# Convert a time value into a nice string
#
sub niceTime($time)
{
   my @modtime=localtime shift;
   my @Months = ( "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" );
   my @Days = ( "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" );
   if ($modtime[1] < 10) { $modtime[1]="0" . $modtime[1]; }
   $modtime[5] += 1900 if ($modtime[5] < 1900);
   my $result="$Days[$modtime[6]], $Months[$modtime[4]] $modtime[3], $modtime[5] at $modtime[2]:$modtime[1]";

   return $result;
}

##############################################################################
#
# Make a safe ID string for the given user
#
sub makeID($user)
{
   my $user = shift;

   my $id = "ID_$user";

   ## Modify our path to escape some characters into URL form...
   $id =~ s|([^a-zA-Z:_])|sprintf("%03o",ord($1))|sego;

   return($id);
}

