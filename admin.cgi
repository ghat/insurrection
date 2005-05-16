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

## Build the list of repositories this user has access to.
my %tlist = %{$usersGroup{$AuthUser}};

## Note that if the user is "root" admin, all groups are listed.
%tlist = %groupUsers if ($isAdmin);

## We like to sort the list just for display reasons...
my @accessGroups = sort keys %tlist;

## Check if this user can administrate other users
my $canAdminUser = $isAdmin;
foreach my $group (@accessGroups)
{
   if (!$canAdminUser)
   {
      $canAdminUser = 1 if (&isAdmin($group,$AuthUser));
   }
}

## Print our standard header...   (Note the 0-minute expires!)
&svn_HEADER('Admin - Insurrection Server','+0m');

print '<h2 align="center">Administration</h2>';

## Now, start figuring out what happened...
my $Operation = $cgi->param('Operation');
$Operation = "" if (!defined $Operation);

if ($Operation eq 'Cancel')
{
   ## Cancelled operation, no special work to do...
}
elsif ($Operation eq 'Update')
{
   ## Lock the access file while we are updating it...
   &lockAccessFile();

   ## Reload the access file, just in case...
   &loadAccessFile();

   if ($accessVersion ne $cgi->param('Access_Version'))
   {
      print '<h2 align="center"><font color="red">Concurrent modification attempted - please recheck</font></h2>'
   }
   else
   {
      ## Just to make sure that someone does not remove his own admin access
      $cgi->param(&makeID($AuthUser,'Admin'),3) if ($isAdmin);

      ## Flag if we actually did change something...
      my $changed = 0;

      foreach my $group (@accessGroups)
      {
         ## Only let me change the group if I am an admin of that group...
         if (&isAdmin($group,$AuthUser))
         {
            ## Ahh, we can change this...
            $changed = 1;

            my %empty;
            %{$groupUsers{$group}} = %empty;

            my ($adminGroup) = ($group =~ /(^[^:]+):/);
            $adminGroup = 'Admin_' . $adminGroup;
            delete $groupAdmins{$adminGroup};

            foreach my $user ('*',keys %userPasswords)
            {
               my $id = &makeID($user,$group);
               my $type = $cgi->param($id);
               if (defined $type)
               {
                  ## The "*" user can only be 0 or 1
                  $type = 1 if (($type > 1) && ($user eq '*'));
                  ${$groupUsers{$group}}{$user} = 'r'  if ($type == 1);
                  ${$groupUsers{$group}}{$user} = 'rw' if ($type > 1);

                  push(@{$groupAdmins{$adminGroup}},$user) if ($type == 3);
               }
            }
         }
      }

      ## And, for the real admin, we need to check for admin groups
      if ($isAdmin)
      {
         $changed = 1;
         my @users;
         foreach my $user (keys %userPasswords)
         {
            push @users,$user if ($cgi->param(&makeID($user,'Admin')) == 3);
         }
         @{$groupAdmins{'Admin'}} = @users;
      }

      if ($changed)
      {
         &saveAccessFile('admin.cgi: Access file updated');

         ## Reload it again (to get the new accessVersion)
         &loadAccessFile();

         ## Only print that there were changes if there really were
         if ($accessVersion ne $cgi->param('Access_Version'))
         {
            print '<h2 align="center"><font color="green">Access controls successfully changed.</font></h2>';
         }
      }
   }

   &unlockAccessFile();
}
elsif ($Operation eq 'AddUser')
{
   ## Only add users if given that right
   if ($canAdminUser)
   {
      my $user = $cgi->param('NewUser');
      chomp $user;

      if ($user =~ /^[a-z][-.@a-z0-9_]+$/)
      {
         ## Lock the password file...
         &lockPasswordFile();

         ## Reload passwordfile...
         &loadPasswordFile();

         if (defined $userPasswords{$user})
         {
            print '<h2 align="center"><font color="red">User already exists.</font></h2>'
         }
         else
         {
            my $pw = &genPassword();
            $userPasswords{$user} = crypt($pw,$pw);
            &savePasswordFile("admin.cgi: Added user $user");

            if (open EMAIL,'| /usr/sbin/sendmail -t')
            {
               print EMAIL 'From: "Insurrection Administrator" <' , &emailAddress($AuthUser) , '>' , "\n"
                         , 'Return-Path: <' , &emailAddress($AuthUser) , '>' , "\n"
                         , 'Subject: Insurrection account created' , "\n"
                         , 'To: "New Insurrection User" <' , &emailAddress($user) , '>' , "\n"
                         , "\n"
                         , "A user access account has been created on the Insurrection Server\n"
                         , "for username $user by user $AuthUser\n"
                         , "\n"
                         , "Your initial random password is: $pw\n"
                         , "\n"
                         , "You can change your password via " , $SVN_URL , $SVN_URL_PATH , "password.cgi\n"
                         , "\n"
                         , "Please go to $SVN_URL$SVN_URL_PATH for information and documentation\n"
                         , "about the Insurrection server.\n"
                         , "\n"
                         , 'This EMail was produced on ' , &niceTime(time) , "\n"
                         , 'The request was done from ' , $cgi->remote_host() , "\n"
                         , 'The user agent was ' , $cgi->user_agent() , "\n"
                         , "\n"
                         , "-- \n"
                         , "Insurrection Server - $SVN_URL$SVN_URL_PATH\n";

               close EMAIL;
            }
            else
            {
               print '<h2 align="center"><font color="red">Failed to send EMail to ' , $user , $EMAIL_DOMAIN , '</font></h2>';
            }

            print '<h2 align="center"><font color="green">User successfully added.</font></h2>';
         }

         &unlockPasswordFile();
      }
      else
      {
         print '<h2 align="center"><font color="red">Invalid characters in username.</font></h2>'
      }
   }
}
elsif ($Operation eq 'Delete User')
{
   my $user = $cgi->param('delUsername');
   if (&canDelete($user))
   {
      ## Clear the user from memory...
      delete $userPasswords{$user};

      ## Lock the password file for the duration...
      &lockPasswordFile();

      ## Reload the password file
      &loadPasswordFile();

      ## The user should have been reloaded, so delete them...
      ## But, if someone already did, ignore it...
      if (defined $userPasswords{$user})
      {
         delete $userPasswords{$user};
         &savePasswordFile("admin.cgi: Deleted user $user");

         print '<h2 align="center"><font color="green">User ' , $user , ' successfully deleted.</font></h2>';
      }

      &unlockPasswordFile();
   }
   else
   {
      print '<h2 align="center"><font color="red">User ' , $user , ' can not be deleted.</font></h2>';
   }
}
elsif (defined $cgi->param('delUser'))
{
   my $user = $cgi->param('delUser');
   if (&canDelete($user))
   {
      print '<form action="?" method="post">'
          , '<input type="hidden" name="delUsername" value="' , $user , '"/>'
          , '<h2 align="center">Delete user ' , $user , '?&nbsp; <input type="submit" name="Operation" value="Delete User"/>&nbsp;<input type="submit" name="Operation" value="Cencel"/></h2>'
          , '</form><hr>';
   }
   else
   {
      print '<h2 align="center"><font color="red">User ' , $user , ' can not be deleted.</font></h2>'
          , '<p>In order to delete the user, all access rights must be removed from the user first.</p>';
   }
}

print '<center>';

## If the user has any direct/specific rights, show them
if (@accessGroups > 0)
{
   print '<p style="font-size: 9pt; text-align: left;">This page lets you administer the Insurrection access rights.&nbsp;'
       , 'The access chart below shows the users that have read/write access to the given repositories/paths.</p>' if ($canAdminUser);

   ## Print the table...
   my $cols = scalar @accessGroups;

   ## The labels for the different states
   my @buttons = ('-','ro','r/w','Adm');

   ## Order the group list such that groups the user has
   ## admin rights to will be seen first.
   my @newList;
   for (my $modType = 1; $modType >= 0; $modType--)
   {
      foreach my $group (@accessGroups)
      {
         if ($modType == &isAdmin($group,$AuthUser))
         {
            push @newList,$group;
         }
      }
   }
   @accessGroups = @newList;

   if ($canAdminUser)
   {
      print '<script type="text/javascript" language="JavaScript"><!--' , "\n"
          , 'var states = new Array();';

      for (my $i = 0; $i < @buttons; $i++)
      {
         print 'states[' , $i , '] = "' , $buttons[$i] , '";';
      }

      print 'function bump(me,id)'
          , '{'
          ,   'var val = document.getElementById(id);'
          ,   'var t = val.value;'
          ,   't++;'
          ,   'if (t > 3) {t = 0;}'
          ,   'val.value = t;'
          ,   'me.innerHTML = states[t];'
          , '}'
          , 'function bump0(me,id)'
          , '{'
          ,   'var val = document.getElementById(id);'
          ,   'var t = val.value;'
          ,   't++;'
          ,   'if (t > 1) {t = 0;}'
          ,   'val.value = t;'
          ,   'me.innerHTML = states[t];'
          , '}';

      print 'function bump1(me,id)'
          , '{'
          ,   'var val = document.getElementById(id);'
          ,   'var t = val.value;'
          ,   'if (t == 0) {t = 3;} else {t = 0}'
          ,   'val.value = t;'
          ,   'me.innerHTML = states[t];'
          , '}' if ($isAdmin);

      print '//--></script>'
          , '<form action="?" method="post">'
          , '<input type="hidden" name="Access_Version" value="' , &svn_XML_Escape($accessVersion) , '"/>';
   }

   print '<table border="0" cellpadding="2" cellspacing="0"><tr><td>'
       , '<table class="accesstable" cellspacing="0">'
       , '<tr><th rowspan="2">Username</th>';
   print '<th rowspan="2">Admin</th>' if ($isAdmin);
   print '<th align="center" colspan="' , $cols , '">Repositories</th>'
       , '</tr>'
       , '<tr class="accesstitles">';

   foreach my $group (@accessGroups)
   {
      print '<th>' , $group , '</th>';
   }
   print '</tr>';

   my $line = 0;
   my @lineColour = ('#EEEEEE' , '#DDDDDD');  ## Alternating line colours
   my @flagColour = ('#CCFFCC' , '#BBEEBB');  ## Flag what the values were before changes
   my $canMod = 0;

   my $formEntries = '';

   foreach my $user ('*', sort keys %userPasswords)
   {
      if ($canAdminUser || ($AuthUser eq $user))
      {
         print '<tr bgcolor="' , $lineColour[$line] , '">'
             , '<td align="left" valign="middle">&nbsp;';

         print '<a href="?delUser=' , &svn_XML_Escape($user) , '">' if (&canDelete($user));
         print &svn_XML_Escape($user);
         print '&nbsp;Anonymous&nbsp;*' if ($user eq '*');
         print '</a>' if (&canDelete($user));
         print '&nbsp;</td>';

         my $bump = 'bump';
         $bump = 'bump0' if ($user eq '*');

         if ($isAdmin)
         {
            if ($user eq '*')
            {
               print '<td nowrap align="center" valign="middle">' , $buttons[0] , '</td>';
            }
            else
            {
               my $id = &makeID($user,'Admin');
               my $val = 0;
               $val = 3 if (&isAdminMember('Admin',$user));
               $formEntries .= '<input type="hidden" name="' . $id . '" id="' . $id . '" value="' . $val . '"/>';
               print '<td nowrap align="center" valign="middle" class="editable"'
                   , ' title="Change access" onmousedown="bump1(this,\'' , $id , '\');"'
                   , '>' , $buttons[$val] , '</td>';
            }
         }

         foreach my $group (@accessGroups)
         {
            my $mod = &isAdmin($group,$AuthUser);
            $canMod = 1 if ($mod);
            my $id = &makeID($user,$group);
            my $val = &typeMember($group,$user);

            $formEntries .= '<input type="hidden" name="' . $id . '" id="' . $id . '" value="' . $val . '"/>' if ($mod);
            print '<td nowrap align="center" valign="middle"';
            print ' class="editable"'
                , ' title="Change access" onmousedown="' , $bump , '(this,\'' , $id , '\');"' if ($mod);
            print '>' , $buttons[$val] , '</td>';
         }
         print '</tr>';

         $line = 1 - $line;
      }
   }

   print '<tr bgcolor="#AAAAAA">'
       ,  '<td align="left" valign="middle">'
       ,   '<input type="text" name="NewUser" value="" size="16" maxlength="32"/>'
       ,  '</td>'
       ,  '<td align="left" valign="middle" colspan="' , ($cols + $isAdmin) , '">'
       ,   '<table width="100%" cellspacing="0" id="versions">'
       ,    '<tr>'
       ,     '<th rowspan="2"><input type="submit" name="Operation" value="AddUser"/></th>'
       ,     '<td>' , &svn_XML_Escape($accessVersion) , '</td>'
       ,    '</tr>'
       ,    '<tr><td width="90%">' , &svn_XML_Escape($passwdVersion) , '</td></tr>'
       ,   '</table>'
       ,  '</td>'
       , '</tr>' if ($canAdminUser);

   print '</table></td></tr>';
   print '<tr>'
       , '<td align=right><input type="submit" name="Operation" value="Update"/></td>'
       , '</tr>' if ($canMod);
   print '</table>';

   print '<p style="font-size: 9pt; text-align: left;">To add a user, you must use the email address of the user.&nbsp; '
       , 'For example, <b>msinz</b>' , $EMAIL_DOMAIN , ' would need to used.&nbsp; '
       , 'This is important as EMail is used to send the initial password to the user.</p>' if ($canAdminUser);

   print $formEntries , '</form>' if ($canAdminUser);

   print '<br/>';
}

print &repositoryTable();

print '</center>';

&svn_TRAILER('$Id$');

# all done...
exit 0;

##############################################################################
#
# Make an EMail address from a user name if the user name is not already in
# an EMail form...
#
sub emailAddress($user)
{
   my $user = shift;
   $user .= $EMAIL_DOMAIN if (!($user =~ /@/));
   return $user;
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
# Check if the user can be deleted by the current authenticated user...
#
sub canDelete($user)
{
   my $user = shift;
   my $canDel = 0;
   if ($canAdminUser)
   {
      if ((defined $user) && (defined $userPasswords{$user}) && ($user ne $AuthUser))
      {
         ## Check to see if this user has access anywhere else
         ## Only full admins can delete users that have other access
         $canDel = 1 if ($isAdmin || (!defined $usersGroup{$user}));
      }
   }
   return($canDel);
}

##############################################################################
#
# Make a safe ID string for the given user and group combination.
#
sub makeID($user,$group)
{
   my $user = shift;
   my $group = shift;

   my $id = "ID_$user:$group";

   ## Modify our path to escape some characters into URL form...
   $id =~ s|([^a-zA-Z:_])|sprintf("%03o",ord($1))|seg;

   return($id);
}

