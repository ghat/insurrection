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
 * the result.
 */
function loadBannerCheck(target)
{
	if ((target.xml) && (target.xml.readyState == 4) && (target.xml.status == 200))
	{
		var txt = target.xml.responseText;

		// If there are no HTML tags in the .svn_index
		// then we will assume it is plain ascii and
		// needs to be '<pre>' wrapped
		if (txt.indexOf('<') < 0)
		{
			txt = '<pre>' + txt + '</pre>';
		}

		target.innerHTML = txt;
		target.style.display = 'block';

		// Remove the reference to the loaded document
		target.xml = null;
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
	var target = document.getElementById('localbanner');
	if (target)
	{
		target.xml = getXMLHTTP();
		if (target.xml)
		{
			target.xml.onreadystatechange = function() { loadBannerCheck(target); };
			target.xml.open("GET",name,true);
			target.xml.send(null);
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
function doNextItem(actionList)
{
	// Do up to 3 entries at a time...
	// Why 3?  Why not - just a number that seemed to fit
	// It could be as low as 1 or as high as you want...
	// To large and the browser "hangs" while it does all
	// the work on a large directory.  Too low and the
	// directory takes longer to display...
	var bunchCount = 3;

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
			td.className = 'pathname';
			tr.appendChild(td);

			a = document.createElement('a');
			a.href = tgt;
			a.title = 'Go to directory "' + action.name + '"';
			td.appendChild(a);
			div = document.createElement('div');
			div.className = 'dir';

			// Get the detail info if available...
			addRevInfo(div,action);

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
			td.className = 'pathname';
			tr.appendChild(td);

			a = document.createElement('a');
			a.href = tgt;
			a.title = 'Get latest version of "' + action.name + '"';
			td.appendChild(a);
			div = document.createElement('div');
			div.className = 'file';

			// Get the detail info if available...
			addRevInfo(div,action);

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

	// If there are still things to do, do them after a
	// small timeout (just to keep the browser responsive)
	if (actionList.length > 0)
	{
		setTimeout(function() {doNextItem(actionList);},1);
	}
}

/*
 * This common bit of code will conditionally add the
 * extended revision info if it is in the action item.
 */
function addRevInfo(a,action)
{
	if (action.rev)
	{
		var span = document.createElement('span');
		span.className = 'revinfo-date';
		span.appendChild(document.createTextNode(action.date));
		a.appendChild(span);

		span = document.createElement('span');
		span.className = 'revinfo-rev';
		span.appendChild(document.createTextNode('r' + action.rev));
		a.appendChild(span);

		span = document.createElement('span');
		span.className = 'revinfo-author';
		span.appendChild(document.createTextNode(action.author));
		a.appendChild(span);
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

	// We need this action list...
	var actionList = new Array();

	// build the list of directory actions...
	var dirs = responseXML.getElementsByTagName('dir');
	for (var i=0; i < dirs.length; i++)
	{
		var action = new Object();
		action.target = target;
		action.type = 'dir';
		action.name = dirs[i].getAttribute('name');
		action.href = dirs[i].getAttribute('href');

		// In case the extended data is available, add it too...
		if (dirs[i].getAttribute('revision'))
		{
			action.rev = dirs[i].getAttribute('revision');
			action.author = dirs[i].getAttribute('author');
			action.date = dirs[i].getAttribute('date');
		}
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

		// In case the extended data is available, add it too...
		if (files[i].getAttribute('revision'))
		{
			action.rev = files[i].getAttribute('revision');
			action.author = files[i].getAttribute('author');
			action.date = files[i].getAttribute('date');
		}
		actionList.push(action);
	}

	// Ask the system to process the list...
	doNextItem(actionList);
}

/*
 * This is the nasty part of the in-line directory loading
 * code.  When the result comes back, load the XML into
 * action items to update the DOM.  This is done in these
 * stages such that we can give the browser some time
 * to respond to user actions while doing all of this
 * DOM work.  This is important since the DOM work
 * can be rather significant.
 */
function loadDirCheck(target)
{
	if ((target.xml) && (target.xml.readyState == 4))
	{
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

	if (target)
	{
		target.arrow = arrow;
		target.row = document.getElementById(target.id + '/');
		if (target.row)
		{
			target.xml = getXMLHTTP();
			if (target.xml)
			{
				// Flip the arrow and start showing the rows now...
				foldDir(arrow);

				// Set the internal text such that we know where we are...
				target.innerHTML = 'xml.open("GET","' + target.id + '",true);';

				target.xml.onreadystatechange = function() { loadDirCheck(target); };
				target.xml.open("GET",target.id + '?XMLHttp=1',true);
				target.xml.send(null);
			}
		}
	}
}

