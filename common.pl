#
# $Id$
# Copyright 2004,2005 - Michael Sinz
#
# This is some common code that all of the Perl code
# needs.  Note that this includes the default configuration
# file such that only this code needs to know to include it.
require 'insurrection.pl';

## Read the insurrection.xsl file for configuration information.
## The configuration is within the XSL file due to problems with
## certain browsers not supporting the XPath document() function.
my $insurrection_xml = '';
if (open(INSURRECTION,'<insurrection.xsl'))
{
   $insurrection_xml = join('',<INSURRECTION>);
   close(INSURRECTION);
}

##
## This function does the XML escaping for the '&', '<', '>', and '"'
## characters.  The first 3 are absolutely required and the last one
## enables putting the string within quoted parameters.
sub svn_XML_Escape($str)
{
   my $str = shift;

   $str =~ s/&/&amp;/sg;
   $str =~ s/</&lt;/sg;
   $str =~ s/>/&gt;/sg;
   $str =~ s/"/&quot;/sg;

   return $str;
}

##
## This function just does the %xx escaping of a string
## for use within URLs.  Even though it is so small, it
## is easier to maintain in one place rather than have
## it all over the place.
sub svn_URL_Escape($path)
{
   my $path = shift;

   ## Modify our path to escape some characters into URL form...
   $path =~ s|([^-.A-Za-z0-9/_])|sprintf("%%%02X",ord($1))|seg;

   return $path;
}

##
## This function takes a repository path from the URL
## and makes it into a local file:// URL.  It also
## makes sure that external ".." operations are not
## allowed to reach outside of the repository.
sub svn_URL($path)
{
   my $path = shift;

   if (defined $path)
   {
      ## Prevent ugly hacks from getting into my pathinfo...
      ## (The only one I care about is the '..')
      $path =~ s:(\.\./)|(/\.\.)|(^\.\.$)::g;

      ## Get rid of trailing '/'
      $path =~ s:/+$::;

      ## Fix up/escape as needed...
      $path = &svn_URL_Escape($path);

      ## Now, prepend the base and file:// URL construct
      $path = 'file://' . $SVN_BASE . $path;
   }

   return $path;
}

##
## This function takes a repository path from the URL
## and returns the local repository name information
sub svn_REPO($path)
{
   my $path = shift;

   if (defined $path)
   {
      ## Prevent ugly hacks from getting into my pathinfo...
      ## (The only one I care about is the '..')
      $path =~ s:(\.\./)|(/\.\.)|(^\.\.$)::g;

      ## Note that only the first element is used, so
      ## get rid of anything after the first element.
      $path =~ s:^/([^/]+).*$:$1:;
   }

   return $path;
}

##
## This function takes a repository path from the URL
## and returns the relative path from within the repository
sub svn_RPATH($path)
{
   my $path = shift;

   if (defined $path)
   {
      ## Prevent ugly hacks from getting into my pathinfo...
      ## (The only one I care about is the '..')
      $path =~ s:(\.\./)|(/\.\.)|(^\.\.$)::g;

      ## Get rid of trailing '/'
      $path =~ s:/+$::;

      ## Note that only the first element is used, so
      ## get rid of anything after the first element.
      if ($path =~ m:^/[^/]+(/.*)$:)
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

sub svn_HEADER($title)
{
   my $title = shift;
   my ($header) = ($insurrection_xml =~ m|<xsl:template name="header">(.*?)</xsl:template>|s);
   my ($banner) = ($insurrection_xml =~ m|<xsl:template name="banner">(.*?)</xsl:template>|s);

   print 'Expires: Fri Dec 31 19:00:00 1999' , "\n"
       , 'Cache-Control: no-cache' , "\n"
       , 'Content-type: text/html' , "\n"
       , "\n"
       , '<!doctype HTML PUBLIC "-//W2C//DTD HTML 4.01 Transitional//EN">' , "\n"
       , '<html>'
       ,  '<head>'
       ,   '<title>' , $title , '</title>'
       ,   $header
       ,  '</head>' , "\n"
       ,  '<body>'
       ,   '<table id="pagetable"><tr><td id="content">'
       ,    $banner
       ,    '<div class="svn">' , "\n";
}

sub svn_TRAILER($version,$AuthUser)
{
   my $version = shift;
   my $AuthUser = shift;

   print '</div><div class="footer">' , $version;
   print '&nbsp;&nbsp;&nbsp;--&nbsp;&nbsp;&nbsp;'
       , 'You are logged on as: <b>' , $AuthUser , '</b>' if (defined $AuthUser);
   print '</div></td></tr></table></body></html>';
}


return 1;

