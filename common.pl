#
# $Id$
# Copyright 2004,2005 - Michael Sinz
#
# This is some common code that all of the Perl code
# needs.  Note that this includes the default configuration
# file such that only this code needs to know to include it.
require 'insurrection.pl';

my $insurrection_xml = '';
if (open(INSURRECTION,'<insurrection.xml'))
{
   $insurrection_xml = join('',<INSURRECTION>);
   close(INSURRECTION);
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

      ## Modify our docpath to match have escaped spaces
      $path =~ s/ /%20/g;

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

   my ($header) = ($insurrection_xml =~ m:<header>(.*)</header>:s);
   my ($banner) = ($insurrection_xml =~ m:<banner>(.*)</banner>:s);

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

