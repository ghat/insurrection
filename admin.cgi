#!/usr/bin/perl
#
# $Id$
# Copyright 2004,2005 - Michael Sinz
#
# This script handles the various administrative
# operations for a specific repository.
#
require 'admin.pl';

## First, lets see if we are the admin of the repository...
&checkAdminMode();

## We will need this...
&loadAccessFile() if (!defined %groupUsers);

## For now we only support full repository management.  I plan to add
## sub-path management later
my $group = &svn_REPO() . ':/';

## Make sure that the anon user is listed (even if no-access)
${$groupUsers{$group}}{'*'} = '' if (!defined ${$groupUsers{$group}}{'*'});

## Make sure we mark the page as expiring right away...
&svn_HEADER('Administration of ' . &svn_REPO(),'+0m');

print '<div style="font-size: 20pt; text-align: center; padding-bottom: 3px; margin-bottom: 2px; border-bottom: 1px green dotted;">Repository:&nbsp;'
    ,  '<span style="font-weight: bold;">' , &svn_REPO() , '</span>'
    , '</div>';

if (defined $cgi->param('update'))
{
   ## Ok, so an update of the access lists is in order.  Lets lock
   ## the access file and try to get ready...
   &lockAccessFile();
   &loadAccessFile();

   ## Make sure that the anon user is listed (even if no-access)
   ${$groupUsers{$group}}{'*'} = '' if (!defined ${$groupUsers{$group}}{'*'});

   print '<center>' , &startInnerFrame('Action log: Update access rights');

   if ($accessVersion ne $cgi->param('version'))
   {
      print '<h2 style="color: red;">Concurrent modification attempted<br/>Please recheck data and submit again</h2>'
   }
   else
   {
      my $actions = '';
      my $changed = 0;
      my $adminGroup = 'Admin_' . &svn_REPO();
      my %admins;
      foreach my $user (@{$groupAdmins{$adminGroup}})
      {
         $admins{$user} = 1;
      }

      ## We need to know if we are "super-user" such that we can
      ## also change our own status...
      my $isAdmin = &isAdminMember('Admin',$AuthUser);

      foreach my $user (sort keys %{$groupUsers{$group}})
      {
         ## One can not change your own settings...
         ## This prevents an admin from removing
         ## admin rights from himself and thus leaving
         ## the repository without an admin!
         ## Note that "super-user" does not have this problem.
         if (($user ne $AuthUser) || ($isAdmin))
         {
            my $id = &makeID($user);
            my $newType = $cgi->param($id);
            if (defined $newType)
            {
               if (($newType > 3) || ($newType < 0))
               {
                  delete ${$groupUsers{$group}}{$user};
                  delete $admins{$user} if (defined $admins{$user});
                  $actions .= "\tDeleting the user $user\n";
               }
               else
               {
                  if (($newType < 3) && (defined $admins{$user}))
                  {
                     delete $admins{$user};
                     $actions .= "\tRemoving admin rights from user $user\n";
                  }

                  if (($newType > 1) && (${$groupUsers{$group}}{$user} ne 'rw'))
                  {
                     ${$groupUsers{$group}}{$user} = 'rw';
                     $actions .= "\tGiving read/write repository access to user $user\n";
                  }

                  if (($newType == 1) && (${$groupUsers{$group}}{$user} ne 'r'))
                  {
                     ${$groupUsers{$group}}{$user} = 'r';
                     $actions .= "\tGiving read-only repository access to user $user\n";
                  }

                  if (($newType == 0) && (${$groupUsers{$group}}{$user} ne ''))
                  {
                     ${$groupUsers{$group}}{$user} = '';
                     $actions .= "\tRemoving all repository access from user $user\n";
                  }

                  if (($newType == 3) && (!defined $admins{$user}))
                  {
                     $admins{$user} = 1;
                     $actions .= "\tGiving admin rights to user $user\n";
                  }
               }
            }
         }
      }

      if (length($actions) > 0)
      {
         ## Rebuild the admins array (it may be what changed)
         @{$groupAdmins{$adminGroup}} = sort keys %admins;

         ## Save and reload the access file...
         print '<pre>' , $actions , '</pre>';
         &saveAccessFile("admin.cgi: Updated access file for group $group\n\n$actions");
         &loadAccessFile();
      }
   }
   &unlockAccessFile();

   print &endInnerFrame() , '</cetner>';
}
elsif (defined $cgi->param('adduser'))
{
   ## Since there is little in the way of "old" to deal with.
   my $user = $cgi->param('NewUser');
   chomp $user;

   ## Show the action log...
   print '<center>' , &startInnerFrame('Action log: Add User');

   ## Only simple characters in the user name and nothing too long
   ## Ok, we picked the size limit out of thin air but it is a reasonable limit.
   if (($user =~ /^[a-z][-.@a-z0-9_]+$/o) || (length($user) < 64))
   {

      ## Lock the password file...
      &lockPasswordFile();

      ## Reload passwordfile...
      &loadPasswordFile();

      if (!defined $userPasswords{$user})
      {
         my $pw = &genPassword();
         $userPasswords{$user} = crypt($pw,$pw);
         $userDates{$user} = 0;  ## The user never changed his password yet...
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
                      , "You can change your password via " , &svn_HTTP() , $SVN_URL_PATH , "password.cgi\n"
                      , "\n"
                      , 'Please go to ' , &svn_HTTP() , $SVN_URL_PATH , "for information and documentation\n"
                      , "about the Insurrection server.\n"
                      , "\n"
                      , 'This EMail was produced on ' , &niceTime(time) , "\n"
                      , 'The request was done from ' , $cgi->remote_host() , "\n"
                      , 'The user agent was ' , $cgi->user_agent() , "\n"
                      , "\n"
                      , "-- \n"
                      , 'Insurrection Server - ' , &svn_HTTP() , $SVN_URL_PATH , "\n";

            close EMAIL;

            print '<h2 style="color: green;">New user EMail sent to ' , &svn_XML_Escape(&emailAddress($user)) , '</h2>';
         }
         else
         {
            print '<h2 style="color: red;">Failed to send EMail to ' , &svn_XML_Escape(&emailAddress($user)) , '</h2>';
         }
      }

      &unlockPasswordFile();

      ## Now, we want to try to add the user to the repository user list
      ## with no access to start out with...
      &lockAccessFile();
      &loadAccessFile();

      if (!defined ${$groupUsers{$group}}{$user})
      {
         ${$groupUsers{$group}}{$user} = '';
         &saveAccessFile("admin.cgi: Added user $user to group $group");
         &loadAccessFile();
      }
      else
      {
         print 'User ' , &svn_XML_Escape($user) , ' already exists';
      }

      &unlockAccessFile();
   }
   else
   {
      print '<h2 style="color: red;">Invalid characters in username.</h2>';
   }
   print &endInnerFrame() , '</center>';
}

&printAdminForms();

&svn_TRAILER('$Id$');

sub printAdminForms()
{
   print '<center>';

   ##############################################################################
   ### User access administration form
   print '<form method="post" action="?Insurrection=admin">'
       , '<input type="hidden" name="version" value="' , &svn_XML_Escape($accessVersion) , '"/>'
       , &startTableFrame(undef,'User Name&nbsp;',undef,'Access rights',undef);

   my @accessLevels = ('No Access','Read Only','Full Access','Administrator','Delete User');

   foreach my $user (sort keys %{$groupUsers{$group}})
   {
      my $u = $user;
      my $levels = @accessLevels;

      if ($user eq '*')
      {
         $u = '* Anonymous *';
         $levels = 2;
      }

      my $type = &typeMember($group,$user);

      my $access = '<select name="' . &makeID($user) . '" size="1">';
      for (my $i=0; $i < $levels; $i++)
      {
         $access .= '<option value="' . $i . '"';
         $access .= ' selected' if ($i == $type);
         $access .= '>' . $accessLevels[$i] . '</option>';
      }
      $access .= '</select>';

      print &doTableFrameRow(&svn_XML_Escape($u),'nowrap style="padding-right: 1em; text-align: left;"'
                            ,$access,'style="padding-left: 1em; text-align: left;"');
   }

   print &doTableFrameRow('<input type="reset"/>','align="left"',
                          '<input type="submit" name="update" value="Save Changes"/>','align="right"');

   print &endTableFrame()
       , '</form>';
   ### User access administration form
   ##############################################################################

   print '</center>';
   print '<table width="100%" cellpadding="0" cellspacing="0"><tr><td align="left" valign="top">';

   ##############################################################################
   ### Add new user form
   print '<form method="post" action="?Insurrection=admin">'
       , &startInnerFrame('Add new user')
       , '<p>'
       ,  '<input type="hidden" name="Insurrection" value="admin"/>'
       ,  '<input type="text" name="NewUser" value="" size="28" maxlength="56" title="Enter the EMail address of the new user"/>'
       ,  '<input type="submit" name="adduser" value="Add"/>'
       , '</p>'
       , '<p>'
       ,  'To add a new user, enter their EMail address above.'
       , '</p>'
       , '<p>'
       ,  'After the new user has been added, '
       ,  'you can then assign access rights to that user.'
       , '</p>'
       , '<p>'
       ,  'If the account is new to the server, the server will '
       ,  'send an EMail to that user with the access credentials '
       ,  'needed to log in.'
       , '</p>'
       , &endInnerFrame()
       , '</form>';
   ### Add new user form
   ##############################################################################

   print '</td><td valign="top" align="center" width="50%">';

   ##############################################################################
   ### Repository dump form
   print '<form method="get" action="?">'
       , &startInnerFrame('Repository Dump','100%')
       , '<input type="hidden" name="Insurrection" value="dump"/>'
       , '<center>'
       , '<table cellspacing="0" cellpadding="0" style="font-size: 10pt;">'
       ,  '<tr style="vertical-align: baseline">'
       ,   '<td>Options:</td>'
       ,   '<td nowrap>'
       ,    '<input type="checkbox" name="Deltas" checked title="Using deltas significantly reduces the size of the repository dump"/>Use deltas &nbsp;'
       ,    '<input type="checkbox" name="Head" title="Dump only the latest revision"/>Head only'
       ,   '</td>'
       ,  '</tr>'
       ,  '<tr style="vertical-align: baseline">'
       ,   '<td title="Select the compression format to use for the repository dump">Compression:</td>'
       ,   '<td nowrap>'
       ,    '<input type="radio" name="Compress" value="none" title="No compression - not recommened as the a dump could be very large"/>none &nbsp;'
       ,    '<input type="radio" name="Compress" checked value="gzip" title="Standard gzip compression - supported almost everywhere"/>gzip &nbsp;'
       ,    '<input type="radio" name="Compress" value="bz2" title="Enhanced bzip2 compression - somewhat better than gzip but much slower"/>bzip2'
       ,   '</td>'
       ,  '</tr>'
       ,  '<tr>'
       ,   '<td colspan="2" align="center" style="padding-top: 4px;">'
       ,    '<input type="submit" name="Dump" value="Download now"/>'
       ,   '</td>'
       ,  '</tr>'
       , '</table>'
       , '</center>'
       , &endInnerFrame()
       , '</form>';
   ### Repository dump form
   ##############################################################################

   ##############################################################################
   ### Repository usage form

   ## Where the usage history sumary files are stored
   my $USAGE_DIR = $SVN_LOGS . '/usage-history';

   ## The repository directory on the local disk...
   my $repoDir = $SVN_BASE . '/' . &svn_REPO();

   ## Get the size limit for this repository.
   my $diskLimit = &repoSizeLimit(&svn_REPO());

   ## Get the disk space used in the repository.
   my $diskUsage = &repoSize(&svn_REPO());

   ## Make a nice title to popup when showing the usage...
   my $diskUsageTitle = 'using ' . $diskUsage . 'k  [limit: ' . $diskLimit . 'k]';
   while ($diskUsageTitle =~ s/(\d+)(\d\d\d)/$1,$2/o) {}

   ## The bandwidth limit for this repository.
   my $bandwidthLimit = &repoBandwidthLimit(&svn_REPO());

   ## Now for the last few months of bandwidth usage (starting at the newest?)
   ## So, lets read the directory looking for the usage total files
   my $logDir = $USAGE_DIR . '/' . &svn_REPO();
   my $rows = 0;
   my $bw_rows = '';
   if (opendir(DIR,$logDir))
   {
      foreach my $file (reverse sort grep(/^usage-.*\.db$/,readdir(DIR)))
      {
         ## Show up to the last 4 months here?
         if ($rows < 4)
         {
            if (open(DB,"<$logDir/$file"))
            {
               my $bandwidthTotal = <DB>;
               close(DB);
               $bandwidthTotal =~ s/^\D*?(\d+)\D*/$1/so;

               my ($y,$m) = ($file =~ m/(\d\d\d\d)-(\d\d)/o);

               my $month = ('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec')[$m-1];

               my $bandwidthTitle = $bandwidthTotal . ' bytes in ' . $month . '  [limit: ' . $bandwidthLimit . ']';
               while ($bandwidthTitle =~ s/(\d+)(\d\d\d)/$1,$2/o) {}

               $bw_rows .= '<tr>'
                         .  '<td nowrap>' . $month . '&ndash;' . $y . '&nbsp;bandwidth:&nbsp;</td>'
                         .  '<td>' . &gauge($bandwidthTotal,$bandwidthLimit,$bandwidthTitle) . '</td>'
                         . '</tr>';
               $rows++;
            }
         }
      }
      closedir(DIR);
   }

   print &startInnerFrame('Repository Usage','100%')
       , '<table width="100%" cellpadding="0" cellspacing="0">'
       ,  '<tr>'
       ,   '<td>Repository&nbsp;size:&nbsp;</td>'
       ,   '<td width="99%">' , &gauge($diskUsage,$diskLimit,$diskUsageTitle) , '</td>'
       ,  '</tr>'
       ,  $bw_rows
       , '</table>'
       , '<center>'
       ,  '<form method="get" action="?" style="margin: 2px;">'
       ,   '<input type="hidden" name="Insurrection" value="bandwidth"/>'
       ,   '<input type="submit" name="go" value="View current summary"/>'
       ,  '</form>'
       ,  '<form method="get" action="?" style="margin: 2px;">'
       ,   '<input type="hidden" name="Insurrection" value="bandwidth"/>'
       ,   '<input type="hidden" name="Details" value="1"/>'
       ,   '<input type="submit" name="go" value="View daily details"/>'
       ,  '</form>'
       ,  '<form method="get" action="' , $SVN_REPOSITORIES_URL , &svn_REPO() , '/.raw-details./index.html" style="margin: 2px;">'
       ,   '<input type="hidden" name="Insurrection" value="bandwidth"/>'
       ,   '<input type="submit" name="go" value="View raw details"/>'
       ,  '</form>'
       , '</center>'
       , &endInnerFrame();
   ### Repository usage form
   ##############################################################################

   print '</td></tr></table>';
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

