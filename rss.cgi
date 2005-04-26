#!/usr/bin/perl
#
# $Id$
# Copyright 2004,2005 - Michael Sinz
#
# This script handles the return of rss data.
#
require 'admin.pl';

## First, lets see if we are allowed to look here:
&checkAuthPath($cgi->path_info);

## For the RSS data we will show up to 2 days ago
## (you can change that here to be something else)
## Thus you will always get at least 1 entry
## and no more than 2 days worth of entries.
my $RSS_RANGE = '2 days';

## Build the end date of the log request...
my $endDate = `date "+%FT%T" -d "$RSS_RANGE ago"`;
chomp $endDate;
my $rev = "-r 'HEAD:{" . $endDate . "}' ";

## Months of the year (1 - 12)
my @months = ('?','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec');

## Get the local document URL
my $rssURL = &svn_URL($cgi->path_info);

## Split the repository from the path within the repository
my $rpath = &svn_REPO($cgi->path_info);
my $opath = &svn_RPATH($cgi->path_info);

## Now, lets build the correct command to run...
my $cmd = $SVN_CMD . ' log -v --stop-on-copy --xml ' . $rev . $rssURL;

my $log;
my $top;
my $topDate;
if ((defined $rpath)
   && (defined $opath)
   && (open(LOGXML,"$cmd |")))
{
   $log = join('',<LOGXML>);
   close(LOGXML);

   ($top) = ($log =~ m:(<\?.*?\?>):s);

   ## Get the first date I can find...
   ($topDate) = ($log =~ m:<date>(.*?)</date>:s);
}

if ((defined $log)
    && (defined $top)
    && (defined $topDate))
{
   print "Content-type: text/xml\n"
       , "\n"
       , $top , "\n"
       , "<!-- Insurrection Web Tools for Subversion RSS Feed -->\n"
       , "<!-- Copyright (c) 2004,2005 - Michael Sinz         -->\n"
       , "<!-- http://www.sinz.org/Michael.Sinz/Insurrection/ -->\n"
       , '<rss version="2.0">'
       , '<channel>' , "\n"
       , '<title>Repository: ' , &svn_XML_Escape($rpath) , '</title>' , "\n"
       , '<description>RSS Feed of the activity in the "' , &svn_XML_Escape($rpath)
       ,   '" repository over the last ' , $RSS_RANGE , '.&amp;nbsp; '
       ,   '&lt;br/&gt; ' , &svn_XML_Escape($groupComments{$rpath . ':/'})
       , '</description>' , "\n"
       , '<link>' , &svn_XML_Escape($SVN_URL . $SVN_REPOSITORIES_URL . $rpath . $opath) , '</link>' , "\n"
       , '<generator>Insurrection RSS Feeder - '
       ,   &svn_XML_Escape('$Id$')
       , '</generator>' , "\n"
       , '<pubDate>' , &dateFormat($topDate) , '</pubDate>'
       , '<lastBuildDate>' , &dateFormat($topDate) , '</lastBuildDate>' , "\n";

   foreach my $entry ($log =~ m|(<logentry\s.*?</logentry>)|sg)
   {
      my ($revision) = ($entry =~ m:revision="(.+?)">:s);
      my ($author) = ($entry =~ m:<author>(.*?)</author>:s);
      my ($logmsg) = ($entry =~ m:<msg>(.*?)</msg>:s);
      my ($date) = ($entry =~ m:<date>(.*?)</date>:s);

      ## Convert line enders into <br/>
      $logmsg =~ s:\n:<br/>:sg;

      ## If the author does not have a domain, add the default one
      $author .= $EMAIL_DOMAIN if (!($author =~ m/@/));

      ## Make the link to this individual log message.
      my $link = $SVN_URL . $SVN_URL_PATH . 'log.cgi/' . $rpath . $opath . '?r1=' . $revision . '&r2=' . $revision;

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
   &svn_HEADER('SVN RSS - Subversion Server');

   print '<h1>Failed to access the log</h1>'
       , '<h3>Log command:</h3>'
       , '<pre>' , $cmd , '</pre>';

   &svn_TRAILER('$Id$',$cgi->remote_user);
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
