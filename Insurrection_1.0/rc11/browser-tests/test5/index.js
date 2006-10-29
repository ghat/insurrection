/*
 * $Id$
 * Copyright 2004-2006 - Michael Sinz
 *
 * Some JavaScript support routines for the svn test index pages
 */

/*
 * Yuck!  I hate doing browser-specific stuff.
 * But at least by doing it in this way we can
 * support the older IE-specific XMLHttpRequest
 * object while still doing it the standards way
 * and not actually checking the browser user
 * agent string.
 */
function getXMLHTTP()
{
	var xml=null;

	// First, if we have the "standard" XMLHttpRequest
	// object defined in this browser, use it...
	if (window.XMLHttpRequest)
	{
		xml=new XMLHttpRequest();
	}
	else if (window.ActiveXObject)
	{
		// Ok, no XMLHttpRequest but we do have the
		// ActiveXOjbect feature.  Maybe the object
		// that is supported is the Msxml2 version?
		try
		{
			xml=new ActiveXObject("Msxml2.XMLHTTP");
		}
		catch(e)
		{
			// Ok, so if not that version, lets try the
			// generic Microsoft version.  (How annoying
			// that Microsoft does not even remain
			// consistant in its own naming.)
			try
			{
				xml=new ActiveXObject("Microsoft.XMLHTTP");
			}
			catch(ee)
			{
				xml=null;
			}
		}
	}

	return xml;
}

var target = null;
function loadBanner(name)
{
	target = document.getElementById('banner');
	if (target)
	{
		target.innerHTML = '<h1>We found the target of the load...</h1>';
		target.xml = getXMLHTTP();
		if (target.xml)
		{
			target.innerHTML = '<h1>We have an XML HTTP object...</h1>';
			target.xml.onreadystatechange = loadCheck;
			target.xml.open('GET',name,true);
			target.xml.send(null);
		}
	}
}

function loadCheck()
{
	if ((target) && (target.xml) && (target.xml.readyState == 4))
	{
		if (target.xml.status == 200)
		{
			target.innerHTML = target.xml.responseText;
		}
		else
		{
			target.innerHTML = '<h1>Load error: ' + target.xml.status + '</h1>';
		}
	}
}

