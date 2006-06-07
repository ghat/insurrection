/*
 * $Id$
 * Copyright 2004-2006 - Michael Sinz
 *
 * Check for HTTPS connections and warn if it is not an
 * https connection by rendering a display in the
 * current location.
 */

/*
 * When we get loaded, put in a bit of extra warning if the
 * connection is not HTTPS and make the link point to the
 * same URL only with "https" protocol.
 */
if (document.location.toString().indexOf('https://') != 0)
{
	// Figure out what our new URL will look like...
	var url = document.location.toString();
	url = 'https' + url.substring(url.indexOf(':'));

	// Add our little element for showing the HTTPS warning...
	document.write('<div class="NoHTTPS" title="Click the link to go to the secure HTTPS url"><b>Warning!</b>&nbsp; You are not connected via an encrypted HTTPS session.&nbsp; We recommend that you go to the secure, encrypted, HTTPS URL at:&nbsp; ' + url.link() + '</div>');
}

