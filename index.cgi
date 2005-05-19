#!/usr/bin/perl
#
# $Id$
# Copyright 2004,2005 - Michael Sinz
#
# This script takes the index.html template and inserts some
# specific dynamic content into it.
#
# Note that we track the changes via Subversion itself - that
# is, the access file is in the Subversion repository
#
require 'admin.pl';

open INDEX,"<index.template" || die "Where is index.template?";
my $index = join('',<INDEX>);
close INDEX;

my $repoTable = &repositoryTable();

$index =~ s:<repos/>:$repoTable:sge;

## Now, set up the buttons area HTML and put that into the
## template.  Note that we do this here because we need
## to know about the login state...
my $buttons = '<table width="100%" cellpadding="6" cellspacing="0" border="0">';
$buttons   .= '<tr>';
$buttons   .=   '<td nowrap width="33%" align="left">';
$buttons   .=    '<a class="linkbutton" href="password.cgi">Change your password</a>' if (defined $AuthUser);
$buttons   .=   '</td>';
$buttons   .=   '<td nowrap width="34%" align="center">';
$buttons   .=    '<a class="linkbutton" href="admin.cgi">Manage users</a>' if (defined $AuthUser);
$buttons   .=   '</td>';
$buttons   .=   '<td nowrap width="33%" align="right">';
$buttons   .=    '<a class="linkbutton" href="auth_index.cgi">Login</a>' if (!defined $AuthUser);
$buttons   .=   '</td>';
$buttons   .=  '</tr>';
$buttons   .= '</table>';

$index =~ s:<buttons/>:$buttons:sge;

&svn_HEADER('MKSoft Insurrection Server');

print $index;

&svn_TRAILER('$Id$');

