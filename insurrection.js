/*
 * $Id$
 * Copyright 2004,2005 - Michael Sinz
 *
 * Some JavaScript configuration variables.
 * Set these to match your environment.
 *
 * Don't forget the matching insurrection.pl and insurrection.xml files.
 */

var Insurrection = new Object();

/*
 * This is the URL to the base of the repositories.
 * The form of the URL should be <base>/<repository>/<repofiles>
 *
 * For example, /svn/Web/trunk/... would be '/svn/' for the
 * base path, 'Web' for the repository name, and '/trunk/...' for
 * the files in the repository.
 */
Insurrection.Repositories_URL = '/svn/';

/*
 * This is the base URL for where the Insurrection CGIs live
 * This should include a leading and trailing '/' character.
 * (or just a single '/' if the CGIs are at the root.)
 */
Insurrection.CGI_URL = '/';

/*
 * Number of animation steps in the unfolding of the popups
 * To have things happen instantly then set this value to 1.
 */
Insurrection.SliderSteps = 12;

/*
 * Note - you should not need to change these unless you named
 * the CGIs differently from the default names.
 */

/*
 * This is the URL for the log.cgi
 */
Insurrection.log_CGI = Insurrection.CGI_URL + 'log.cgi';

/*
 * This is the URL for the get.cgi
 */
Insurrection.get_CGI = Insurrection.CGI_URL + 'get.cgi';

/*
 * This is the URL for the diff.cgi
 */
Insurrection.diff_CGI = Insurrection.CGI_URL + 'diff.cgi';

/*
 * This is the URL for the blame.cgi
 */
Insurrection.blame_CGI = Insurrection.CGI_URL + 'blame.cgi';

