#!/usr/bin/perl
#
# $Id$
# Copyright 2004,2005 - Michael Sinz
#
# This script handles the return of atom data.
#
require 'admin.pl';

## First, lets see if we in good standing...
&checkAuthMode();

## The maximum number of entries to be returned in
## the Atom Feed.  This is just in case there was
## a very busy period in the repository.
my $MAX_ENTRIES = 20;

## For the Atom data we will show up to n days worth
## of activity as long as it is less than the above
## number of entries.
my $ATOM_DAYS_RANGE = 7;

## Rough guess as to the number of days in a month...
##           ('?','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec');
my @monthDays = (0, 31,   28,   31,   30,   31,   30,   31,   31,   30,   31,   30,   31);
## Yes, yes, I know that Feb has 29 days every so often.  But
## we don't really care if we got a little bit of extra data
## every once in a while...  So we just ignore that fact...

## Get the local document URL
my $atomURL = &svn_URL();

## Split the repository from the path within the repository
my $rpath = &svn_REPO();
my $opath = &svn_RPATH();

## What we are going to do here is just get the log entry for the
## head revision and use it to find out the date of the last
## entry.  Then, we use the date formula to figure out how
## far back to ask for.  This is all done in the hopes of not
## needing to get the whole revision history and then trimming
## it.  We really just want the last n days (but no more than
## MAX_ENTRIES) from the last entry date.
##
## This gives us useful Atom feeds even for repositories that
## have been quiet.

## We first look for the HEAD revision to find out the time
## of the newest revision...
my $rev = '-r HEAD ';

## Arg - svn log -r HEAD does not really work if there are no
## current changes in this part of the tree.  So, we need to
## find the most current revision first, using svn ls -v
## and looking for the largest revision almost works except
## that the directory may be newer than any of its contents
## so we then need to get all revisions from the HEAD to
## that highest revision (without copies).  Usually this
## will result in 1 or 2 entries at most, but it requires
## that "svn ls -v" run first, which is extra overhead.
## Since this is not needed at the root of the repository
## we don't do it unless we are not at the root.
## (The root always has every revision since it is all paths)
if ($opath ne '/')
{
   my $cmd = $SVN_CMD . ' ls -v ' . $atomURL;
   my $lastR = 0;
   foreach my $rline (split("\n",`$cmd`))
   {
      if ($rline =~ m/^\s*(\d+)\s+/o)
      {
         my $r = 0 + $1;
         $lastR = $r if ($r > $lastR);
      }
   }
   $rev = "-r HEAD:$lastR ";
}

my $cmd = $SVN_CMD . ' log --non-interactive --no-auth-cache --xml --stop-on-copy ' . $rev . $atomURL;
my $hdata = `$cmd`;
if ($hdata =~ m:<date>\s*(.*?)\s*</date>:so)
{
   ## Date format:  2005-05-07T02:41:02.820786Z
   my $firstDate = $1;

   ## Check if this is the same as before...
   if ("\"$firstDate\"" eq $ENV{'HTTP_IF_NONE_MATCH'})
   {
      ## The user tells me he already has this one...
      print $cgi->header('-Status' => '304 Not Modified');
      exit 0;
   }

   if ($firstDate =~ m/^(\d+)-(\d+)-(\d+)(T.*)$/o)
   {
      my $year = $1;
      my $month = $2;
      my $day = $3;
      my $rest = $4;

      $day = $day - $ATOM_DAYS_RANGE;
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
$cmd = $SVN_CMD . ' log --non-interactive --no-auth-cache --xml --stop-on-copy --verbose ' . $rev . $atomURL;

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
   @entries = ($log =~ m|(<logentry\s.*?</logentry>)|sgo);

   ## Drop all of the entries that are beyond our limit...
   while (@entries > $MAX_ENTRIES)
   {
      pop @entries;
   }

   ## Get our XML intro so we can match the encodings.
   ## (We are not changing any bytes of content, so it will
   ## be whatever was given to us.
   if ($log =~ m:(<\?xml.*?\?>):so)
   {
      $top = $1;
      if ($top =~ m/encoding="(.*?)"/so)
      {
         $encoding = $1;
      }
   }

   ## Get the date of the first entry
   if ($entries[0] =~ m:<date>\s*(.*?)\s*</date>:so)
   {
      $topDate = $1;
   }

   ## And the date of the last entry
   if ($entries[@entries - 1] =~ m:<date>\s*(.*?)\s*</date>:so)
   {
      $endDate = $1;
   }
}

if ((defined $top) && (defined $topDate))
{
   ## Check if we have loaded the admin stuff yet...
   &loadAccessFile() if (!defined %groupComments);

   ## Note that Atom feeds expire after 120 minutes...
   ## Also, we use ETag and Last-Modified such that we can
   ## return conditional get results.  Note that we only really
   ## look at the ETag so we don't worry about making a valid
   ## Last-Modified header.
   print $cgi->header('-expires' => '+120m' ,
                      '-Last-Modified' => &dateFormat($topDate) ,
                      '-ETag' => "\"$topDate\"" ,
                      '-type' => 'text/xml; charset=' . $encoding);

   my $rLink = &svn_HTTP() . &svn_URL_Escape($SVN_REPOSITORIES_URL . $rpath . $opath) . '?Insurrection=log';

   print $top , "\n"
       #, '<?xml-stylesheet type="text/xsl" href="' , $SVN_URL_PATH , 'insurrection.xsl"?>' , "\n"
       , "<!-- Insurrection Web Tools for Subversion Atom Feed -->\n"
       , "<!-- Copyright (c) 2004,2005 - Michael Sinz          -->\n"
       , "<!-- http://www.sinz.org/Michael.Sinz/Insurrection/  -->\n"
       , '<feed version="0.3" xmlns="http://purl.org/atom/ns#">' , "\n"
       , '<title>Repository: ' , &svn_XML_Escape($rpath . ': ' . $opath) , '</title>' , "\n"
       , '<tagline type="text/html" mode="escaped">Atom Feed of the activity in "' , &svn_XML_Escape($opath)
       ,   '" of the "' , &svn_XML_Escape($rpath)
       ,   '" repository from ' , &dateFormat($topDate)
       ,   ' to ' , &dateFormat($endDate) , '. &lt;hr/&gt;'
       ,   &svn_XML_Escape($groupComments{$rpath . ':/'})
       , '</tagline>' , "\n"
       , '<link rel="alternate" type="text/html" href="' , &svn_XML_Escape($rLink) , '"/>' , "\n"
       , '<generator>Insurrection Atom Feeder - '
       ,   &svn_XML_Escape('$Id$')
       , '</generator>' , "\n"
       , '<modified>' , $topDate , '</modified>';

   foreach my $entry (@entries)
   {
      my ($revision) = ($entry =~ m:revision="(.+?)">:so);
      my ($author) = ($entry =~ m:<author>\s*(.*?)\s*</author>:so);
      my ($logmsg) = ($entry =~ m:<msg>\s*(.*?)\s*</msg>:so);
      my ($date) = ($entry =~ m:<date>\s*(.*?)\s*</date>:so);

      ## Convert line enders into <br/>
      $logmsg =~ s:\n:<br/>:sgo;

      ## Make the link to this individual log message.
      my $link = $rLink . '&r=' . $revision;

      ## Now finish building the log message...
      $logmsg = '<div>'
                . $logmsg
                . &listFiles('Added','A',$entry)
                . &listFiles('Modified','M',$entry)
                . &listFiles('Replaced','R',$entry)
                . &listFiles('Deleted','D',$entry)
                . '</div>';

      ## Output this item...
      print '<entry>' , "\n"
          , '<title>Revision ' , $revision , '</title>'
          , '<issued>' , $date , '</issued>'
          , '<modified>' , $date , '</modified>'
          , '<author><name>' , $author , '</name></author>' , "\n"
          , '<id>' , &svn_XML_Escape($link) , '</id>' , "\n"
          , '<link rel="alternate" type="text/html" href="' , &svn_XML_Escape($link) , '"/>' , "\n"
          , '<content type="text/html" mode="escaped">' , &svn_XML_Escape($logmsg) , '</content>' , "\n"
          , '</entry>' , "\n";
   }
   print "</feed>\n";
}
else
{
   print "Status: 404 Log Not Available\n";
   &svn_HEADER('SVN Feed - Insurrection Server');

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

