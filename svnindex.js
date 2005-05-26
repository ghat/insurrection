/*
 * $Id$
 * Copyright 2004,2005 - Michael Sinz
 *
 * Some JavaScript support routines for the svn index pages
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

/*
 * This is the callback function from the XMLHttpRequest
 * which then, if the request completes correctly, displays
 * the result.  It is annoying that the callback does not
 * provide the XMLHttpRequest object, so I have to store
 * it globally.
 */
var _target = null;
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
function loadBanner(name)
{
	// Check if the load is already in progress...
	if (_target == null)
	{
		var target = document.getElementById('localbanner');
		if (target)
		{
			target.xml = getXMLHTTP();
			if (target.xml)
			{
				_target = target;
				target.xml.onreadystatechange = loadBannerCheck;
				target.xml.open("GET",name,true);
				target.xml.send(null);
			}
		}
	}
}

/*
 * This is to support the changing of the visible state and the arrow.
 */
function foldDir(arrow)
{
	var target = document.getElementById('.' + arrow.id);
	if (target)
	{
		var row = document.getElementById(target.id + '/');
		if (row)
		{
			if (row.style.display == 'none')
			{
				row.style.display = '';
				arrow.src = document.getElementById('openedImage').src;
				arrow.title = 'Collapse directory';
			}
			else
			{
				row.style.display = 'none';
				arrow.src = document.getElementById('closedImage').src;
				arrow.title = 'Expand directory';
			}
			arrow.alt = arrow.title;
		}
	}
}

/*
 * We dynamically generate the in-line subdirectory DOM elements.
 * We do this "a few at a time" such that the browser remains
 * responsive during the potentially long operation.  It does
 * mean that the browser will tend to render the stuff rather
 * often and thus overall be slower but the responsiveness is
 * worth the trouble.
 *
 * We also manually generate the DOM entries rather than using
 * an innerHTML trick since the innerHTML trick would require
 * that the browser reparse all of the information and that we
 * correctly escape all of the attributes.  Since a file name
 * could contain any character, using the DOM creation method
 * eliminates that problem.  We also find our images from the
 * hiddent images that the XSLT generated.
 */
var actionList = new Array();
var actionTimer = null;
function doNextItem()
{
	if (actionTimer != null)
	{
		actionTimer = null;

		// Do up to 4 entries at a time...
		var bunchCount = 4;

		// Some variables that we will use...
		var tr;
		var td;
		var a;
		var img;
		var div;
		var txt;

		while ((actionList.length > 0) && (bunchCount > 0))
		{
			bunchCount--;
			var action = actionList.shift();
			var tgt = action.target.id + action.href;

			// Check if this is the root index, and if so, load it...
			// This is here to support the broken XSLT browsers.
			if (tgt == './.svn_index')
			{
				loadBanner('.svn_index');
			}

			tr = document.createElement('tr');
			action.target.dirlist.appendChild(tr);

			if (action.type == 'dir')
			{
				tr.className = 'dirrow';

				td = document.createElement('td');
				tr.appendChild(td);

				td.className = 'foldspace';
				img = document.createElement('img');
				img.className = 'dirarrow';
				img.title = 'Expand directory';
				img.alt = img.title;
				img.id = tgt.substring(1);
				img.src = document.getElementById('closedImage').src;
				img.align = 'middle';
				td.appendChild(img);

				// Yes, this is a strange way to set the onclick method
				// but due to IE not being fully consistant in the DOM/JS
				// interface.  But, this happens to be the "other" way to
				// set this onclick property...
				img['onclick'] = function(){loadDir(this);};

				td = document.createElement('td');
				td.width = '99%';
				tr.appendChild(td);

				a = document.createElement('a');
				a.href = tgt;
				a.title = 'Go to directory "' + action.name + '"';
				td.appendChild(a);
				div = document.createElement('div');
				div.className = 'dir';
				a.appendChild(div);
				img = document.createElement('img');
				div.appendChild(img);
				img.src = document.getElementById('dirImage').src;
				img.alt = 'Folder';
				img.className = 'svnentryicon';
				img.align = 'middle';
				img.alt = a.title;
				div.appendChild(document.createTextNode(action.name + '/'));
			}
			else
			{
				tr.className = 'filerow';

				td = document.createElement('td');
				tr.appendChild(td);
				td.className = 'foldspace';
				img = document.createElement('img');
				img.src = document.getElementById('spacerImage').src;
				img.alt = '';
				img.align = 'middle';
				td.appendChild(img);

				td = document.createElement('td');
				td.width = '99%';
				tr.appendChild(td);

				a = document.createElement('a');
				a.href = tgt;
				a.title = 'Get latest version of "' + action.name + '"';
				td.appendChild(a);
				div = document.createElement('div');
				div.className = 'file';
				a.appendChild(div);
				img = document.createElement('img');
				div.appendChild(img);
				img.src = document.getElementById('fileImage').src;
				img.alt = 'File';
				img.className = 'svnentryicon';
				img.align = 'middle';
				img.alt = a.title;
				div.appendChild(document.createTextNode(action.name));
			}

			// The 3rd column for both files and directories is the
			// same, so we do that outside of the separate elements.
			// (This is the "showlog" icon/action)
			td = document.createElement('td');
			tr.appendChild(td);

			td.className = 'showlog';
			a = document.createElement('a');
			td.appendChild(a);

			if (action.type == 'dir')
			{
				a.title = 'Show revision history for directory "' + action.name + '"';
			}
			else
			{
				a.title = 'Show revision history for file "' + action.name + '"';
			}

			a.href = tgt + '?Insurrection=log';
			img = document.createElement('img');
			img.src = document.getElementById('infoImage').src;
			img.align = 'middle';
			img.alt = a.title;
			a.appendChild(img);

			// Directories also have a hidden second row where the
			// in-line sub-directory expansion happens.  Fun stuff
			if (action.type == 'dir')
			{
				tr = document.createElement('tr');
				tr.style.display = 'none';
				tr.id = tgt + '/';
				action.target.dirlist.appendChild(tr);

				td = document.createElement('td');
				tr.appendChild(td);
				td.className = 'foldspace';
				img = document.createElement('img');
				img.src = document.getElementById('spacerImage').src;
				img.alt = '';
				img.align = 'middle';
				td.appendChild(img);

				td = document.createElement('td');
				tr.appendChild(td);
				td.id = tgt;
				td.colSpan = 2;
			}
		}
	}

	// If there are still things to do, go do them...
	if ((actionTimer == null) && (actionList.length > 0))
	{
		actionTimer = setTimeout('doNextItem();',1);
	}
}

/*
 * Given a target object and the completed XMLHttpRequest
 * object, this builds the job list for showing the directory.
 */
function loadDirTarget(target,responseXML)
{
	// Change the onclick to just fold the directory as
	// we have completed the load...
	target.arrow['onclick'] = function(){foldDir(this);};

	// Clear our HTML container before we start building this.
	target.innerHTML = '';

	// Create the table and table body for the subdirectory
	var table = document.createElement('table');
	target.appendChild(table);
	table.width = '100%';
	table.cellSpacing = 0;
	table.cellPadding = 0;
	var tbody = document.createElement('tbody');
	table.appendChild(tbody);

	// Keep track of the table body...
	target.dirlist = tbody;

	// build the list of directory actions...
	var dirs = responseXML.getElementsByTagName('dir');
	for (var i=0; i < dirs.length; i++)
	{
		var action = new Object();
		action.target = target;
		action.type = 'dir';
		action.name = dirs[i].getAttribute('name');
		action.href = dirs[i].getAttribute('href');
		actionList.push(action);
	}

	// build the list of file actions...
	var files = responseXML.getElementsByTagName('file');
	for (var i=0; i < files.length; i++)
	{
		var action = new Object();
		action.target = target;
		action.type = 'file';
		action.name = files[i].getAttribute('name');
		action.href = files[i].getAttribute('href');
		actionList.push(action);
	}

	// Ask the system to do the next action...
	doNextItem();
}

/*
 * This is the nasty part of the in-line directory loading
 * code.  When the result comes back, we expand it as needed.
 * It is a shame that the callback does not
 * give me the XMLHttpRequest object and thus
 * we need to use globals.
 */
var _loadTarget = null;
function loadDirCheck()
{
	var target = _loadTarget;
	if ((target) && (target.xml) && (target.xml.readyState == 4))
	{
		// We are done with this one...
		_loadTarget = null;

		// Set the internal text just in case of an error:
		target.innerHTML = target.id + ' : ' + target.xml.status + ' : ' + target.xml.statusText;

		// Save and remove the reference to the loaded document
		var xml = target.xml;
		target.xml = null;

		// If all is well, actually deal with the result...
		if (xml.status == 200)
		{
			// All done and good - so actually load the directory.
			loadDirTarget(target,xml.responseXML);
		}
	}
}

/*
 * In order to support in-line directory expansion, the directory
 * arrow calls us like this...
 */
function loadDir(arrow)
{
	// Find our target and make sure we are not in the middle
	// of doing one already...
	var target = document.getElementById('.' + arrow.id);
	if ((target) && (_loadTarget == null))
	{
		target.arrow = arrow;
		target.row = document.getElementById(target.id + '/');
		if (target.row)
		{
			target.xml = getXMLHTTP();
			if (target.xml)
			{
				// We have to keep a global to find ourselves again...
				_loadTarget = target;

				// Flip the arrow and start showing the rows now...
				foldDir(arrow);

				// Set the internal text such that we know where we are...
				target.innerHTML = 'xml.open("GET","' + target.id + '",true);';

				target.xml.onreadystatechange = loadDirCheck;
				target.xml.open("GET",target.id + '?XMLHttp=1',true);
				target.xml.send(null);
			}
		}
	}
}

