#!/usr/bin/perl
#
# $Id$
# Copyright 2004,2005 - Michael Sinz
#
# This script handles the return of a slightly better XML listing
# than the mod_dav_svn does.  The XML schema is basically compatible
# with just some added attributes for the file and directory entries.
#
# !!!NOTE!!! While I belive that this code is fully working and it
# passed the tests I have made for it, it is not the most beautiful
# code nor is it strictly correct.  However, since it does address
# the need and it works reasonably well, I am including it now.
#
require 'admin.pl';

## First, lets see if we in good standing...
&checkAuthMode();

## Get the real document URL
my $docURL = &svn_URL();

my $getls = $SVN_CMD . ' ls --non-interactive --no-auth-cache --xml ' . $docURL;

my $pathInfo = $cgi->path_info;
my ($repo,$repo_path) = ($pathInfo =~ m|^(/[^/]+)(.*?)/$|o);
$repo_path = '/' if (!($repo_path =~ m|^/|o));

my $ls;
if (open(LS,$getls . ' |'))
{
   $ls = join('',<LS>);
   close(LS);

   ## Check that we actually got something.
   $ls = undef if (!($ls =~ m:<lists>.*?</lists>:so));
}

## What a trick - to get the broken browsers to work.
## Removes the need for XSLT...
##
## Note that the XSLT of Safari is almost working but
## not quite.  So it is listed here.
##
## What we do here is redirect the output of this
## CGI into a server-side XSLT processor when the
## client user-agent string seems to match known
## broken clients.
##
## Note that if someone expressly wants XML, the
## XMLHttp=1 attribute is needed.
##
## Note that we would like to have the real XSLT working
## as there are some things that are not available
## without it *and* the bandwidth and server load are
## much lower.  The good thing is that the top two
## browser technologies do work correctly enough to
## not need this hack.  That ends up covering 98% of
## all wed users.  (That is Mozilla/Firefox and IE)
my $needsXSLT = 1 if (&isBrokenBrowser());
my $sendType = 'text/xml; charset=utf-8';
$sendType = 'text/html' if ($needsXSLT);

if (defined $ls)
{
   my @entries = ($ls =~ m:(<entry.*?>.*?</entry>):sgo);

   print $cgi->header('-expires' => '+120m' ,
                      '-type' => $sendType);

   ## Note, we can just fall-through if this fails.  We would
   ## end up getting XML where we wanted HTML but if we needed
   ## HTML and the xsltproc does not exist, this is no worse
   ## than not even trying.  (And, well, what else could I do?)
   open(STDOUT,'| xsltproc insurrection.xsl -') if ($needsXSLT);

   ## Get the XML version and encoding...
   $ls =~ m:(<\?xml.*?\?>):so;
   print $1 , "\n"
       , '<?xml-stylesheet type="text/xsl" href="' , $SVN_URL_PATH , 'insurrection.xsl"?>' , "\n"
       , "<!-- Insurrection Web Tools for Subversion: svn ls  -->\n"
       , "<!-- Copyright (c) 2004,2005 - Michael Sinz         -->\n"
       , "<!-- http://www.sinz.org/Michael.Sinz/Insurrection/ -->\n"
       , '<!DOCTYPE svn SYSTEM "' , &svn_HTTP() , $SVN_URL_PATH , 'ls.dtd">' , "\n";

   ## Note that we don't include the repository revision as it is
   ## not known without doing yet more overhead - and it really is
   ## not needed in the display.
   print '<svn href="http://www.sinz.org/Michael.Sinz/Insurrection/">'
       , '<index path="' , &svn_XML_Escape($repo_path) , '">' , "\n";

   print "<updir/>\n" if ($repo_path ne '/');

   ## Now, for each "entry" element, we need to make either
   ## a file or directory element in the output.
   foreach my $entry (@entries)
   {
      my ($name) = ($entry =~ m:<name>(.*?)</name>:so);
      my ($rev) = ($entry =~ m:<commit\s+[^>]*revision="(\d+)"[^>]*>:so);
      my ($author) = ($entry =~ m:<author>(.*?)</author>:so);
      my ($date) = ($entry =~ m:<date>(.*?)</date>:so);

      ## Make sure any quotes in the name or author fields are escaped...
      $name =~ s/"/&quot;/sgo;
      $author =~ s/"/&quot;/sgo;

      my $link = $name;
      $link =~ s|([^-\&;.A-Za-z0-9/_])|sprintf("%%%02X",ord($1))|sego;
      $link =~ s|\&amp;|%26|sgo;

      ## Fix the date into the format I want
      $date =~ s|.*(\d\d\d\d)-(\d\d)-(\d\d)T(\d\d:\d\d:\d\d).*|$1/$2/$3 - $4|o;

      if ($entry =~ m/<entry\s+[^>]*kind="dir"[^>]*>/so)
      {
         print '<dir'
             , ' name="' , $name , '"'
             , ' href="' , $link , '/"'
             , ' author="' , $author , '"'
             , ' revision="' , $rev , '"'
             , ' date="' , $date , '"'
             , "/>\n";
      }
      else
      {
         ## A file
         my ($size) = ($entry =~ m:<size>(\d+)</size>:so);

         print '<file'
             , ' name="' , $name , '"'
             , ' href="' , $link , '"'
             , ' author="' , $author , '"'
             , ' revision="' , $rev , '"'
             , ' date="' , $date , '"'
             , ' size="' , $size , '"'
             , "/>\n";
      }
   }

   print '</index></svn>';
}
else
{
   print $cgi->header('-status' => 404)
       , '<html><head><title>Path not found</title></head><body>Path not found</body></html>';
}

