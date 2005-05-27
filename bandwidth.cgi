#!/usr/bin/perl
#
# $Id$
# Copyright 2004,2005 - Michael Sinz
#
# This script displays the bandwidth used for
# the given repository.  Note only repository
# admins or the global admin can access this page.
#
require 'admin.pl';

## First, lets see if we in good standing for this...
&checkAdminMode();

## Where the usage history sumary files are stored
my $USAGE_DIR = $SVN_LOGS . '/usage-history';

## Load upto n-days into the past for this history
## Note that only admins can see more than 1 month worth.
my $MAX_HISTORY = 400;

my $isAdmin = &isAdminMember('Admin',$AuthUser);

my $max_history = $cgi->param('History');
$max_history = $MAX_HISTORY if ((!defined $max_history) || (!$isAdmin));

## Check if we are to show details
my $showDetails = $cgi->param('Details');

## The repository we are playing with...
my $repo = &svn_REPO();
$repo = '' if ($repo eq '/');

my ($raw) = (&svn_RPATH =~ m:/\.raw-details\./(.*):);

## Only the global admin can check on all of the repository details
if (($repo eq '') && (!$isAdmin))
{
   print $cgi->redirect('-location' => $SVN_URL_PATH,
                        '-status' => '302 Invalid path');
   exit 0;
}

## Check to make sure that there is repository data available...
if (!(-d "$USAGE_DIR/$repo"))
{
   print $cgi->redirect('-location' => $SVN_URL_PATH,
                        '-status' => '302 Invalid path');
   exit 0;
}

## Now, if we have no repository, we need to do all of the
## directories in the $USAGE_DIR
if ($repo eq '')
{
   &svn_HEADER('Bandwidth usage');

   my $total = 0;

   foreach $repo (sort split("\n",`ls $USAGE_DIR`))
   {
      $total += &repoUsage($repo);

      print '<hr/>';
   }

   print '<div class="bandwidth bandwidthheader1">'
       ,  &niceNumber($total) , ' bytes total measured bandwidth'
       , '</div>';
}
elsif (defined $raw)
{
   my $file = "$USAGE_DIR/$repo/stats/$raw";

   if ($raw =~ m:.html$:)
   {
      ## Ahh, the HTML - I need to clean it up a bit...
      if (open(RAW,"<$file"))
      {
         my $html = join('',<RAW>);
         close(RAW);

         ## Rip out just we don't want
         $html =~ s|.*<BODY[^>]*>||sg;
         $html =~ s|</BODY[^>]*>.*||sg;
         $html =~ s|<P>.<HR>.<TABLE.*||sg;

         ## Make all of the references to URLs relative to the server...
         $html =~ s|http://Repository\s$repo/|/|sg;

         ## Oh, and all local links and images need the extra parameter if
         ## they are not already done
         $html =~ s:(HREF=|SRC=)"(\./)?([^/"]+)":$1"$3?Insurrection=bandwidth":sg;

         $html =~ s|<H2>(.*?)</H2>|<div style="text-align: center; font-weight: bold; font-size: 20pt;">$1</div>|s;
         $html =~ s|<SMALL><STRONG>(.*?)</STRONG></SMALL>|<div style="text-align: right; font-size: 10pt;">$1</div>|s;

         ## Last bit of fixup...
         $html =~ s|<CENTER>.<HR>(.*)</CENTER>|<div style="background: #EEEEEE; border: 1px black solid; margin-top: 2px; padding: 2px;"><CENTER>$1</CENTER></div>|s;

         &svn_HEADER_oldHTML('Raw Details: ' . $repo);
         print "\n<!-- Begin: HTML generated via legacy software -->\n";
         print $html;
         print "\n<!-- End: HTML generated via legacy software -->\n";
      }
   }
   else
   {
      ## Unknown type, so just send it...
      print $cgi->header('-type' => 'application/octet-stream');
      system('cat',$file);
      exit 0;
   }
}
else
{
   &svn_HEADER('Bandwidth usage: ' . $repo);
   &repoUsage($repo);
}

&svn_TRAILER('$Id$');


##############################################################################
#
# This will output a repository bandwidth usage table and return the total
# usage that was reported in that table.  It is a function here such that
# it can be called for all of the repositories being tracked.
#
# Ugly, hacky code, but it is not used often and I needed to get it done.
# Will clean up later, if it is needed.
#
sub repoUsage($repo)
{
   my $repo = shift;
   my %usage;
   my %totals;
   my $grandTotal = 0;

   my $baseTime = time;
   my $currentMonth;
   my @ltime = localtime($baseTime);

   ## Only stay withing the current month except if there
   ## is a custom history setting... (which only admin can do?)
   for (my $i=0; ($i < $max_history) && ((!defined $currentMonth) || ($currentMonth == $ltime[4]) || ($max_history != $MAX_HISTORY)) ; $i++)
   {
      my $date = sprintf('%4d/%02d/%02d',$ltime[5]+1900,$ltime[4]+1,$ltime[3]);
      my %data = &loadHash($repo,$date);
      if (scalar keys %data)
      {
         ## If this is the first entry we saw, set that as the month
         $currentMonth = $ltime[4] if (!defined $currentMonth);

         my %data = &loadHash($repo,$date);
         %{$usage{$date}} = %data if (scalar keys %data);

         foreach my $user (keys %data)
         {
            $totals{$user} = 0 if (!defined $totals{$user});

            $totals{$user} += $data{$user};
            $grandTotal += $data{$user};
         }
      }

      ## Next time...
      $baseTime -= 60 * 60 * 24;
      @ltime = localtime($baseTime);
   }

   my @dates = sort keys %usage;

   my $title = 'Bandwidth sumary: ' . $repo . ' repository';
   if ($repo =~ /^-.*-$/)
   {
      $title = 'System: ' . $repo;
   }

   print '<div class="bandwidth">'
       , '<div class="bandwidthheader1">'
       ,  $title
       , '</div>'
       , '<div class="bandwidthheader2">'
       ,  &niceNumber($grandTotal) , ' bytes from ' , $dates[0] , ' to ' , $dates[@dates-1]
       , '</div>'
       , '<table class="bandwidthdata" cellspacing="0" cellpadding="0">';

   print '<tr class="bandwidthtitles">'
       ,  '<th' , ($showDetails ? ' rowspan="2"' : '') , '>Username</th>'
       ,  '<th' , ($showDetails ? ' rowspan="2"' : ' width="110"') , '>Usage';

   my $row2 = '</th>';
   if ($showDetails)
   {
      $row2 .= '</tr><tr class="bandwidthtitles">';
      my $lastmonth;
      my $count = 0;
      foreach my $date (@dates)
      {
         if ($date =~ m:^(\d+)/(\d+)/(\d+)$:)
         {
            if ($lastmonth ne "$1/$2")
            {
               print '</th><th colspan="' , $count , '">' , $lastmonth if (defined $lastmonth);
               $count = 0;
               $lastmonth = "$1/$2";
            }
            $count++;
            $row2 .= '<td>' . $3 . '</td>';
         }
      }

      print '</th><th colspan="' , $count , '">' , $lastmonth if (defined $lastmonth);
   }
   print $row2;
   print '</tr>';

   foreach my $user (sort keys %totals)
   {
      print '<tr class="bandwidthdata"><th>' , &svn_XML_Escape($user);
      print 'anon-' if ($user eq '-');
      print '</th>';
      print '<td>' , &gauge($totals{$user},$grandTotal,&niceNumber($totals{$user}) . ' bytes') , '</td>';

      if ($showDetails)
      {
         foreach my $date (@dates)
         {
            my %data = %{$usage{$date}};
            &printNumberCell($data{$user});
         }
      }

      print '</tr>';
   }

   print '<tr class="bandwidthtotal"><th>Total</th>';
   &printNumberCell($grandTotal);
   if ($showDetails)
   {
      foreach my $date (@dates)
      {
         my %data = %{$usage{$date}};
         my $total = 0;
         foreach my $user (keys %data)
         {
            $total += $data{$user};
         }
         &printNumberCell($total);
      }
   }

   print '</tr></table>';

   if (!$showDetails)
   {
      my $link = $cgi->url() . '/' . $repo . '?Details=1';

      ## If we got here via the proxy trick, continue to use it...
      $link = '?Insurrection=bandwidth&Details=1' if ($cgi->param('Insurrection') eq 'bandwidth');

      $link .= '&History=' . $max_history if ($max_history != $MAX_HISTORY);
      $link = &svn_XML_Escape($link);

      print '<div class="bandwidthfooter">'
          ,  '<a href="' , $link , '" class="linkbutton">Show Details</a>'
          , '</div>';
   }
   else
   {
      my $link = $cgi->url() . '/' . $repo . '/.raw-details./index.html?Details=1';

      ## If we got here via the proxy trick, continue to use it...
      $link = $SVN_REPOSITORIES_URL . $repo . '/.raw-details./index.html?Insurrection=bandwidth' if ($cgi->param('Insurrection') eq 'bandwidth');

      $link = &svn_XML_Escape($link);

      print '<div class="bandwidthfooter">'
          ,  '<a href="' , $link , '" class="linkbutton">Raw Details</a>'
          , '</div>';
   }

   print '</div>';

   return($grandTotal);
}

## Simple shortcut that prints the given number or a space if the
## number is 0 or undefined within a <td></td> cell.
sub printNumberCell($num)
{
   my $num = shift;
   $num = 0 if (!defined $num);
   $num = '&nbsp;' if ($num == 0);

   print '<td>' , &niceNumber($num) , '</td>';
}

## This returns a number with commas added to it.
sub niceNumber($num)
{
   my $num = shift;

   ## Cute trick to get comas into the number...
   while ($num =~ s/(\d+)(\d\d\d)/$1,$2/) {}

   return $num;
}

##############################################################################
#
# Load a daily sumary file into a hash...
#
sub loadHash($repo,$date)
{
   my $repo = shift;
   my $date = shift;

   my %hash;

   if (open(DB,"<$USAGE_DIR/$repo/$date.db"))
   {
      while(<DB>)
      {
         if (m/(\S+):(\d+)/)
         {
            $hash{$1} = $2;
         }
      }
      close(DB);
   }

   return(%hash);
}

