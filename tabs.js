/*
 * $Id$
 * Copyright 2004,2005 - Michael Sinz
 *
 * Some JavaScript support routines to make tabbed pages
 */

// We keep track of the tab sets here...
var tabSets = new Array();

/*
 * Initialize the needed information for a tab set.
 * Note that the setName must be unique on a page
 * and must be legal within a HTML id attribute.
 *
 * The tabs needs to be an array of strings used
 * in the titles of the tabs.
 */
function startTabSet(setName,tabs)
{
  tabSets[setName] = new Object();
  tabSets[setName].tabs = tabs;
  tabSets[setName].current = 0;
}

/*
 * Start one of the tab pages.  The setName must
 * be one that was started.  The tab will be the
 * next tab in the list (starting with the first)
 */
function startTabSetPage(setName)
{
  var tabSet = tabSets[setName];
  if (tabSet)
  {
	var tab = tabSet.current;
	tabSet.current++;

    var tabID = 'tab_' + setName + '_' + tab;
    var numTabs = tabSet.tabs.length;
    var numCols = (numTabs * 2) + 1;

    if (tabSet.needsEnd)
    {
      document.write('</td><td class="innerframe-right"></td></tr></tbody></table>');
    }
    tabSet.needsEnd = 1;

    document.write('<table class="innerframe" style="width: 100%; display: none;" border="0" cellspacing="0" cellpadding="0"');
    document.write(' id="' + tabID + '">');
    document.write('<thead><tr>');

    // If the first tab is active, the top right corner needs special care
    if (tab == 0)
    {
      document.write('<td class="innerframe-top-left">');
    }
    else
    {
      document.write('<td class="innerframe-top-left-light">');
    }

    document.write('<img alt="" src="/blank.gif"/></td>');

    for (var i=0; i<numTabs; i++)
    {
      var rightClass = 'innerframe-top-light-right-tab';
      var tabClass = 'innerframe-top-light';

      if (i < tab)
      {
        rightClass = 'innerframe-top-light-left-tab';
      }

      if ((i+1) == tab)
      {
        rightClass = 'innerframe-top-left-tab';
      }

      if (i == tab)
      {
        rightClass = 'innerframe-top-right-tab';
        tabClass = 'innerframe-top';
      }

      document.write('<td class="' + tabClass + '">');
	  if (i != tab)
	  {
		  document.write('<a class="innerframe-tab" title="' + tabSet.tabs[i] + '" href="#" onclick="return clickTab(\'' + setName + '\',' + i + ');">');
	  }
      document.write(tabSet.tabs[i]);
	  if (i != tab)
	  {
		  document.write('</a>');
	  }
      document.write('</td>');
      document.write('<td class="' + rightClass + '"><img alt="" src="/blank.gif"/></td>');
    }

    document.write('<td class="innerframe-top-light-space"></td>');
    document.write('<td class="innerframe-top-right-light"></td>');
    document.write('</tr></thead>');

    document.write('<tfoot><tr>');
    document.write('<td class="innerframe-bottom-left"></td>');
    document.write('<td class="innerframe-bottom" colspan="' + numCols + '"></td>');
    document.write('<td class="innerframe-bottom-right"><img alt="" src="/blank.gif"/></td>');
    document.write('</tr></tfoot>');

    document.write('<tbody><tr>');
    document.write('<td class="innerframe-left"></td>');
    document.write('<td class="innerframe" colspan="' + numCols + '">');
  }
}

/*
 * This ends a tabset and sets up the default tab, if possible, from the cookie
 */
function endTabSet(setName)
{
  var tabSet = tabSets[setName];
  if (tabSet)
  {
    if (tabSet.needsEnd)
    {
      document.write('</td><td class="innerframe-right"></td></tr></tbody></table>');
    }

    var itab = tabGetCookie(setName);

    if ((itab == null) || (itab < 0) || (itab >= tabSet.tabs.length))
    {
      itab = 0;
    }

    clickTab(setName,itab);
  }
}

/*
 * Activate the give tab in the tab set.
 * This will hide any active tab in this tabset.
 */
function clickTab(setName,tab)
{
  var tabSet = tabSets[setName];
  if (tabSet)
  {
    var tabID = 'tab_' + setName + '_' + tab;

    var newTab = document.getElementById(tabID);
    if (newTab)
    {
      if (tabSet.active)
      {
        tabSet.active.style.display = 'none';
      }
      tabSet.active = newTab;
      tabSet.active.style.display = 'block';

      // Set a cookie to tell us that this tab is active
      tabSetCookie(setName,tab);
    }
  }

  return false;
}

/*
 * Get the value of a named cookie.  We use
 * these cookies to get/set configuration like
 * elements without the need for server interaction.
 */
function tabGetCookie(name)
{
    var arg = 'TAB_' + name + "=";
    var alen = arg.length;
    var clen = document.cookie.length;
    var i = 0;

    while (i < clen)
    {
        var j = i + alen;
        if (document.cookie.substring(i, j) == arg)
        {
            var endstr = document.cookie.indexOf (";", j);
            if (endstr == -1)
            {
                endstr = document.cookie.length;
            }
            return unescape(document.cookie.substring(j, endstr));
        }

        i = document.cookie.indexOf(" ", i) + 1;

        if (i == 0)
        {
            return null;
        }
    }
    return null;
}

/*
 * Set a session-temporary cookie...
 * Setting a cookie is just too easy...  Too bad getting the
 * cookie is not as easy.
 */
function tabSetCookie(name, value)
{
    document.cookie = 'TAB_' + name + '=' + escape(value);
}

