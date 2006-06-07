#!/usr/bin/perl
#
# $Id$
# Copyright 2004-2006 - Michael Sinz
#
# A simple display of the invocation of this CGI
#
use CGI;
$cgi = new CGI;

my $path = $cgi->path_info();
my $p2 = $cgi->param('param2');
my $p3 = $cgi->param('param3');
my @params = $cgi->param;

## Assume things are not good...
my $color = '#FF0000';
my $status = 'Failed!';

if ((defined $p2) && (defined $p3) && (@params == 3) && ($path =~ m:^/(.*)/test\.html$:))
{
   ## Looking better, we have some form of complete path_info()
   ## And we have parameter #2 and there are exactly 3 parameters.
   $color = '#FFFF00';
   $status = 'Warning!';

   my $part = $1;

   if (($part eq $p2) && ($path eq $p3))
   {
      $color = '#00DD00';
      $status = 'Working';
   }
}


print $cgi->header('-Cache-Control' => 'no-cache' ,
                   '-type' => 'text/html');

print '<!doctype HTML PUBLIC "-//W2C//DTD HTML 4.01 Transitional//EN">'
    , '<html>'
    ,   '<head>'
    ,     '<title>Insurrection Apache mod_rewrite Tests</title>'
    ,   '</head>'
    ,   '<body style="font-size: 8pt; margin: 0px;" bgcolor="' , $color , '"'
    ,      ' onload="document.getElementById(\'url\').appendChild(document.createTextNode(document.location));">'
    ,     '<center>'
    ,       '<div style="padding: 2px; background-color: white; color: black; margin: 4px; border: 1px solid black;" id="url">URL:&nbsp;</div>'
    ,       '<table cellspacing="3" cellpadding="0" border="0">'
    ,         '<tr><td valign="top">'
    ,           '<table cellpadding="2" border="0" cellspacing="1" bgcolor="black">'
    ,             '<tr><th style="font-size: 12px;" colspan="2" bgcolor="' , $color , '">' , $status , '</th></tr>';

&printRow('cgi->url',$cgi->url);
&printRow('cgi->path_info()',$cgi->path_info());

if (@params > 0)
{
   print '<tr><th colspan=2 bgcolor="#EEEEEE">Params</th></tr>';
   foreach my $p (sort @params)
   {
      &printRow($p,$cgi->param($p));
   }
}

print           '</table>'
    ,         '</td><td valign="top">'
    ,           '<table cellpadding="1" border="0" cellspacing="1" bgcolor="black">';

foreach my $k (sort keys %ENV)
{
   &printRow($k,$ENV{$k});
}

print           '</table>'
    ,         '</td></tr>'
    ,       '</table>'
    ,     '</center>'
    ,   '</body>'
    , '</html>';

exit 0;

sub printRow($key,$value)
{
   my $key = shift;
   my $value = shift;

   print '<tr bgcolor="#DDDDDD">'
       ,  '<td nowrap>' , &escape($key) , '</td>'
       ,  '<td nowrap>' , &escape($value) , '</td>'
       , '</tr>';
}

sub escape($str)
{
   my $str = shift;

   $str =~ s/&/&amp;/sg;
   $str =~ s/</&lt;/sg;
   $str =~ s/>/&gt;/sg;
   $str =~ s/"/&quot;/sg;

   return $str;
}

