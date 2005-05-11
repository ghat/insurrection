#!/usr/bin/perl
#
# $Id$
# Copyright 2004,2005 - Michael Sinz
#
# This script handles the return of rss data.
#
require 'admin.pl';

## First, lets see if we in good standing...
&checkAuthMode();

## The maximum number of entries to be returned in
## the RSS Feed.  This is just in case there was
## a very busy period in the repository.
my $MAX_ENTRIES = 20;

## For the RSS data we will show up to n days worth
## of activity as long as it is less than the above
## number of entries.
my $RSS_DAYS_RANGE = 7;

## Months of the year (1 - 12)
my @months = ('?','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec');
my @monthDays = (0, 31,   28,   31,   30,   31,   30,   31,   31,   30,   31,   30,   31);
## Yes, yes, I know that Feb has 29 days every so often.  But
## we don't really care if we got a little bit of extra data
## every once in a while...  So we just ignore that fact...

## Get the local document URL
my $rssURL = &svn_URL($cgi->path_info);

## Split the repository from the path within the repository
my $rpath = &svn_REPO($cgi->path_info);
my $opath = &svn_RPATH($cgi->path_info);

## What we are going to do here is just get the log entry for the
## head revision and use it to find out the date of the last
## entry.  Then, we use the date formula to figure out how
## far back to ask for.  This is all done in the hopes of not
## needing to get the whole revision history and then trimming
## it.  We really just want the last n days (but no more than
## MAX_ENTRIES) from the last entry date.
##
## This gives us useful RSS feeds even for repositories that
## have been quiet.

my $rev = '-r HEAD ';
my $cmd = $SVN_CMD . ' log --non-interactive --no-auth-cache --xml ' . $rev . $rssURL;
my $hdata = `$cmd`;
if ($hdata =~ m:<date>\s*(.*?)\s*</date>:s)
{
   ## Date format:  2005-05-07T02:41:02.820786Z
   my $firstDate = $1;
   if ($firstDate =~ m/^(\d+)-(\d+)-(\d+)(T.*)$/)
   {
      my $year = $1;
      my $month = $2;
      my $day = $3;
      my $rest = $4;

      $day = $day - $RSS_DAYS_RANGE;
      while ($day < 1)
      {
         $month = $month - 1;
         if ($month < 1)
         {
            $year = $year - 1;
            $month = 12;
         }
         $day = $day + $monthDays[$month]
      }

      $rev = sprintf("-r 'HEAD:{%04d-%02d-%02d%s}' ",$year,$month,$day,$rest);
   }
}

## Now, lets build the correct command to run...
$cmd = $SVN_CMD . ' log --non-interactive --no-auth-cache --xml --stop-on-copy --verbose ' . $rev . $rssURL;

## Default our encoding to UTF-8, just in case we are not
## given one by the server.
my $encoding = 'utf-8';

my $log;
my $top;
my $topDate;
my @entries;
if ((defined $rpath) && (defined $opath))
{
   $log = `$cmd`;

   ## Parse the log into entries array...
   @entries = ($log =~ m|(<logentry\s.*?</logentry>)|sg);

   ## Drop all of the entries that are beyond our limit...
   while (@entries > $MAX_ENTRIES)
   {
      pop @entries;
   }

   ## Get our XML intro so we can match the encodings.
   ## (We are not changing any bytes of content, so it will
   ## be whatever was given to us.
   if ($log =~ m:(<\?xml.*?\?>):s)
   {
      $top = $1;
      if ($top =~ /encoding="(.*?)"/s)
      {
         $encoding = $1;
      }
   }

   ## Get the date of the first entry
   if ($entries[0] =~ m:<date>\s*(.*?)\s*</date>:s)
   {
      $topDate = $1;
   }

   ## And the date of the last entry
   if ($entries[@entries - 1] =~ m:<date>\s*(.*?)\s*</date>:s)
   {
      $endDate = $1;
   }
}

if ((defined $top) && (defined $topDate))
{
   ## Note that RSS feeds expire after 120 minutes...
   print $cgi->header('-expires' => '+120m' ,
                      '-type' => 'text/xml; charset=' . $encoding);

   my $rLink = $SVN_URL . &svn_URL_Escape($SVN_REPOSITORIES_URL . $rpath . $opath) . '?Insurrection=log';

   print $top , "\n"
       , "<!-- Insurrection Web Tools for Subversion RSS Feed -->\n"
       , "<!-- Copyright (c) 2004,2005 - Michael Sinz         -->\n"
       , "<!-- http://www.sinz.org/Michael.Sinz/Insurrection/ -->\n"
       , '<rss version="2.0">'
       , '<channel>' , "\n"
       , '<title>Repository: ' , &svn_XML_Escape($rpath) , '</title>' , "\n"
       , '<description>RSS Feed of the activity in the "' , &svn_XML_Escape($rpath)
       ,   '" repository from ' , &dateFormat($topDate) , ' to ' , &dateFormat($endDate) , '.&lt;hr/&gt; '
       ,   &svn_XML_Escape($groupComments{$rpath . ':/'})
       , '</description>' , "\n"
       , '<link>' , &svn_XML_Escape($rLink) , '</link>' , "\n"
       , '<generator>Insurrection RSS Feeder - '
       ,   &svn_XML_Escape('$Id$')
       , '</generator>' , "\n"
       , '<pubDate>' , &dateFormat($topDate) , '</pubDate>'
       , '<lastBuildDate>' , &dateFormat($topDate) , '</lastBuildDate>' , "\n";

   foreach my $entry (@entries)
   {
      my ($revision) = ($entry =~ m:revision="(.+?)">:s);
      my ($author) = ($entry =~ m:<author>\s*(.*?)\s*</author>:s);
      my ($logmsg) = ($entry =~ m:<msg>\s*(.*?)\s*</msg>:s);
      my ($date) = ($entry =~ m:<date>\s*(.*?)\s*</date>:s);

      ## Convert line enders into <br/>
      $logmsg =~ s:\n:<br/>:sg;

      ## If the author does not have a domain, add the default one
      $author .= $EMAIL_DOMAIN if (!($author =~ m/@/));

      ## Make the link to this individual log message.
      my $link = $rLink . '&r=' . $revision;

      ## Now finish building the log message...
      ## (It get escaped below)
      $logmsg = '<div>'
                . $logmsg
                . &listFiles('Added','A',$entry)
                . &listFiles('Modified','M',$entry)
                . &listFiles('Replaced','R',$entry)
                . &listFiles('Deleted','D',$entry)
                . '</div>';

      ## Output this item...
      print '<item>' , "\n"
          , '<title>Revision ' , $revision , '</title>'
          , '<pubDate>' , &dateFormat($date) , '</pubDate>'
          , '<author>' , $author , '</author>' , "\n"
          , '<link>' , &svn_XML_Escape($link) , '</link>' , "\n"
          , '<description>' , &svn_XML_Escape($logmsg) , '</description>' , "\n"
          , '</item>' , "\n";
   }
   print '</channel>'
       , "</rss>\n";
}
else
{
   print "Status: 404 Log Not Available\n";
   &svn_HEADER('SVN RSS - Insurrection Server');

   print '<h1>Failed to access the log</h1>'
       , '<h3>Log command:</h3>'
       , '<pre>' , $cmd , '</pre>';

   &svn_TRAILER('$Id$');
}

## Build the list of files modified/updated/etc by the revision...
sub listFiles($msg,$tag,$entry)
{
   my $msg = shift;
   my $tag = shift;
   my $entry = shift;

   my @files = ($entry =~ m:<path\s[^>]*action="$tag"[^>]*>(.*?)</path>:sg);

   my $result = '';

   if (scalar(@files) > 0)
   {
      $result .= '<hr/>' . $msg . ': ' . scalar(@files) . '<ul>';
      foreach my $file (sort @files)
      {
         $result .= '<li>' . $file . '</li>';
      }
      $result .= '</ul>';
   }
   return $result;
}

## Convert the Subversion log date format into RFC822 format.
## Note that I do not include the optional "day of week"
sub dateFormat($isodate)
{
   my $isodate = shift;
   my $result = '?';

   if ($isodate =~ m/(\d\d\d\d)-(\d\d)-(\d\d)T(\d\d:\d\d:\d\d)/)
   {
      $result = $3 . ' ' . $months[$2] . ' ' . $1 . ' ' . $4 . ' GMT';
   }

   return $result;
}
