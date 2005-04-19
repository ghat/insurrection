/*
 * $Id$
 * Copyright 2004,2005 - Michael Sinz
 *
 * Some JavaScript support routines for the svn index pages
 */

/*
 * logLink is used to provide the link from the SVN INDEX
 * into the log CGI - this is needed since the SVN INDEX
 * XML does not provide the repository information, just
 * the local path information.  By implementing the feature
 * in this way, I can figure that out by looking at the
 * client's document.location to find the path to the
 * repository.  What happens is that the returned URL is
 * placed into the a.href in the onmouseover event and
 * thus updating the a.href to be the correct URL.
 */
function logLink(link,file)
{
	// We need to know the actual full path to the
	// URL since the Subversion index XML does not
	// provide the repository information.  Here
	// we get that by knowing where that lives in
	// the document.location.
	var path = document.location.toString();
	path = path.substring(path.indexOf(Insurrection.Repositories_URL) - 1 + Insurrection.Repositories_URL.length);

	link.href = Insurrection.log_CGI + path + file;
}

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

/*
 * This function is called if the local banner file was
 * found in the SVN directory being displayed.  It will
 * then use the XMLHttpRequest() feature of the browser
 * (or the MS-IE XMLHTTP feature) to do its work.
 *
 * Note that the localbanner div is hidden by default.
 * It will be shown only if there is XMLHttpRequest
 * support in the browser (and there was a local banner
 * file found in the XML by the XSLT)
 */
var _target = null;
function loadBanner(name)
{
	var target = document.getElementById('localbanner');
	if (target)
	{
		target.xml = getXMLHTTP();
		if (target.xml)
		{
			target.xml.open("GET",name,true);
			target.xml.onreadystatechange = loadBannerCheck;
			_target = target;
			target.xml.send(null);
		}
	}
}

/*
 * This is the callback function from the XMLHttpRequest
 * which then, if the request completes correctly, displays
 * the result.  It is annoying that the callback does not
 * provide the XMLHttpRequest object, so I have to store
 * it globally.
 */
function loadBannerCheck()
{
	var target = _target;
	if (target.xml)
	{
		if (target.xml.readyState == 4)
		{
			if (target.xml.status == 200)
			{
				target.innerHTML = target.xml.responseText;
				target.style.display = 'block';

				// Remove the reference to the loaded document
				target.xml = null;
			}
		}
	}
}


/*
 * In order to support in-line directory expansion, the directory
 * arrow calls us like this...
 */
var _loadTarget = null;
function loadDir(name)
{
	var target = document.getElementById('.' + name.id);
	if (target)
	{
		if (target.done)
		{
			if (target.row.style.display == 'none')
			{
				target.row.style.display = '';
				target.arrow.src = document.getElementById('openedImage').src;
			}
			else
			{
				target.row.style.display = 'none';
				target.arrow.src = document.getElementById('closedImage').src;
			}
		}
		else
		{
			target.arrow = name;
			target.row = document.getElementById(target.id + '_');
			if (target.row)
			{
				target.xml = getXMLHTTP();
				if (target.xml)
				{
					target.xml.open("GET",target.id,true);
					target.xml.onreadystatechange = loadDirCheck;
					_loadTarget = target;
					target.xml.send(null);
				}
			}
		}
	}
}

function loadDirCheck()
{
	var target = _loadTarget;
	if (target.xml)
	{
		if (target.xml.readyState == 4)
		{
			if (target.xml.status == 200)
			{
				var html = '<table border="0" cellpadding="0" cellspacing="0" width="100%">';

				var dirs = target.xml.responseXML.getElementsByTagName('dir');

				for (var i=0; i < dirs.length; i++)
				{
					var d = dirs[i];
					var dname = d.getAttribute('href');
					var t = target.id + dname;

					html += '<tr class="dirrow">';
					html += '<td class="foldspace"><img class="dirarrow" id="' + t.substring(1) + '" onclick="loadDir(this)" src="' + document.getElementById('closedImage').src + '" align="middle"></td>';
					html += '<td><a href="' + t + '"><div class="dir"><img src="' + document.getElementById('dirImage').src + '" class="svnentryicon" align="middle">' + dname + '</div></a></td>';
					html += '<td class="showlog"><a onmouseover="logLink(this,\'' + t + '\');"><img src="' + document.getElementById('infoImage').src + '" align="middle"></a></td>';
					html += '</tr>';

					html += '<tr id="' + t + '_" style="display: none;">';
					html += '<td class="foldspace"><img src="' + document.getElementById('blankImage').src + '" align="middle"></td>';
					html += '<td id="' + t + '" colspan="2"></td>';
					html += '</tr>';
				}

				var files = target.xml.responseXML.getElementsByTagName('file');
				for (var i=0; i < files.length; i++)
				{
					var d = files[i];
					var dname = d.getAttribute('href');
					var t = target.id + dname;

					html += '<tr class="filerow">';
					html += '<td class="foldspace"><img src="' + document.getElementById('blankImage').src + '" align="middle"></td>';
					html += '<td><a href="' + t + '"><div class="file"><img src="' + document.getElementById('fileImage').src + '" class="svnentryicon" align="middle">' + dname + '</div></a></td>';
					html += '<td class="showlog"><a onmouseover="logLink(this,\'' + t + '\');"><img src="' + document.getElementById('infoImage').src + '" align="middle"></a></td>';
					html += '</tr>';
				}

				html += '</table>';

				target.innerHTML = html;
				target.done = 1;

				loadDir(target.arrow);

				// Remove the reference to the loaded document
				target.xml = null;
			}
		}
	}
}
