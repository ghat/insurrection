#!/usr/bin/perl -w 
#
#
#
#
use strict;
use vars qw($cgi $fu $sizewritten);
use CGI;
use Carp;
$cgi = new CGI;
#
#
#
print $cgi->header('-expires' => '+0m',
                      '-type' => 'text/html');
my $path = $cgi->param('Path');
my $repo = $path;
$repo =~ s[/(.*?)/.*$][$1]; 
	   $path =~ s[^/.*?/][/];
print "<html><head>";
if ($cgi->param('dir') eq 'yes'){
    print "<html><head>";

    print "<title>Uploading " . $cgi->param('Path'). " </title>";
    print << "__HTML";
</head><body>
<br/>
<form action='/Insurrection/upload-commit.cgi' method='post' 
      enctype='multipart/form-data'>
To create a new subdirectory at this spot:
<input type=\"hidden\" name=\"makedir\" value=\"true\" />"
<input type='text' name="filename" size="25" value="Directory name here" /><br/>
<input type='submit' value='Create Now '>
__HTML
print "<input type=\"hidden\" name=\"uploadpath\" value=\"". $path ."\" />";
print "<input type=\"hidden\" name=\"repo\" value=\"". $repo ."\" />";

    print << "__HTML";

</form>
<form action='/Insurrection/upload-commit.cgi' method='post' 
      enctype='multipart/form-data'>
  <b>Or to upload a new file:</b>
  Please select a file for upload to the repository: <br/>
    <input type='file' name='ufile' size='30'><br/>
  Please select a name for the file (required): <br>
    <input type='text' name="filename" size="15" /><br/>
  <input type='text' name='logmessage' value="put log message here" /><br/>
  Then press the <font color=red> Upload Now </font> button. <br>
  <input type='submit' value=' Upload Now '>
__HTML
print "<input type=\"hidden\" name=\"uploadpath\" value=\"". $path ."\" />";
print "<input type=\"hidden\" name=\"repo\" value=\"". $repo ."\" />";
print "<input type=\"hidden\" name=\"new\" value=\"true\" />";
print << "__HTML";
</form>
</body></html>
__HTML

} else { 
print "<title>Uploading " . $cgi->param('Path'). " </title>";
print << "__HTML";
</head><body>
<form action='/Insurrection/upload-commit.cgi' method='post' 
      enctype='multipart/form-data'>
  Please select a file for upload to the repository: <br>
    <input type='file' name='ufile' size='30'><p>
  <input type='text' name='logmessage' value="put log message here" /><br/>
  Then press the <font color=red> Upload Now </font> button. <br>
__HTML
print "<input type=\"hidden\" name=\"uploadpath\" value=\"". $path ."\" />";
print "<input type=\"hidden\" name=\"repo\" value=\"". $repo ."\" />";
print << "__HTML";
  <input type='submit' value=' Upload Now '>
</form>
</body></html>
__HTML
}

