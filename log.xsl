<?xml version="1.0"?>
<!-- $Id$ -->
<!-- Copyright 2004,2005 - Michael Sinz -->
<!-- This is my magic Subversion revision history XSLT transform to HTML -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

  <xsl:output method="html"/>

  <!-- The basic template contains our standard header and page title -->
  <xsl:template match="log">
    <html>
      <head>
        <title>
          <xsl:text>Change log - </xsl:text>
          <xsl:value-of select="@repository"/>
          <xsl:text> - </xsl:text>
          <xsl:value-of select="@path"/>
          <xsl:text> - revision </xsl:text>
          <xsl:value-of select="logentry/@revision"/>
        </title>
        <xsl:copy-of select="document('insurrection.xml')/xml/header/*"/>
      </head>
      <body>
        <table id="pagetable">
          <tr>
            <td id="content">
              <xsl:copy-of select="document('insurrection.xml')/xml/banner/*"/>
              <table class="revision" width="100%" cellspacing="0">
                <tr class="logtitle">
                  <td colspan="3">
                    <xsl:value-of select="@repository"/>
                    <xsl:text> - </xsl:text>
                    <xsl:value-of select="@path"/>
                  </td>
                </tr>
                <tr class="logtitle">
                  <td colspan="3">
                      <xsl:text>Change log of revisions </xsl:text>
                      <xsl:value-of select="logentry/@revision"/>
                      <xsl:text> through </xsl:text>
                      <xsl:value-of select="logentry[last()]/@revision"/>
                  </td>
                </tr>
                <tr class="logheader" onclick="toggleAll();">
                  <th class="logheader1">Rev</th>
                  <th class="logheader1">Author</th>
                  <th class="logheader1" width="99%">
                    <table width="100%" border="0" cellspacing="0" cellpadding="0">
                      <tr>
                        <th class="logheader1">Details</th>
                        <th class="revcount" nowrap="1">
                          <xsl:text>(</xsl:text>
                          <xsl:value-of select="count(logentry)"/>
                          <xsl:text> revision</xsl:text>
                          <xsl:if test="count(logentry) != 1">
                            <xsl:text>s</xsl:text>
                          </xsl:if>
                          <xsl:text>)</xsl:text>
                        </th>
                        <th id="details" width="99%">
                        </th>
                      </tr>
                    </table>
                  </th>
                </tr>

                <!-- We pull of of the log entries here    -->
                <!-- Note that the table format must match -->
                <xsl:apply-templates select="logentry"/>

              </table>

              <!-- If we have a morelog tag, we need to provide a way to get it -->
              <xsl:apply-templates select="morelog"/>

              <div class="footer">
                <xsl:text>$Id$</xsl:text>
              </div>
            </td>
          </tr>
        </table>
      </body>
    </html>
  </xsl:template>

  <!-- For more log entries (older) we have this template -->
  <xsl:template match="morelog">
    <div class="morelog">
      <xsl:element name="a">
        <xsl:attribute name="href">
          <xsl:value-of select="@href"/>
        </xsl:attribute>
        <xsl:text>next page...</xsl:text>
      </xsl:element>
    </div>
  </xsl:template>

  <!-- revision log entries are handled in this template... -->
  <xsl:template match="logentry">
    <xsl:variable name="date">
      <xsl:value-of select="date"/>
    </xsl:variable>
    <tr><td class="spacer" colspan="3"></td></tr>
    <xsl:element name="tr">
      <xsl:attribute name="class">revision</xsl:attribute>
      <xsl:element name="th">
        <xsl:attribute name="class">revision</xsl:attribute>
        <xsl:attribute name="onclick">
          <xsl:text>toggle(</xsl:text>
          <xsl:value-of select="@revision"/>
          <xsl:text>);</xsl:text>
        </xsl:attribute>
        <xsl:value-of select="@revision"/>
      </xsl:element>
      <xsl:element name="td">
        <xsl:attribute name="class">user</xsl:attribute>
        <xsl:attribute name="onclick">
          <xsl:text>toggle(</xsl:text>
          <xsl:value-of select="@revision"/>
          <xsl:text>);</xsl:text>
        </xsl:attribute>
        <xsl:value-of select="author"/>
      </xsl:element>
      <xsl:element name="td">
        <xsl:attribute name="class">details</xsl:attribute>
        <xsl:element name="span">
          <xsl:attribute name="onclick">
            <xsl:text>toggle(</xsl:text>
            <xsl:value-of select="@revision"/>
            <xsl:text>);</xsl:text>
          </xsl:attribute>
          <xsl:variable name="pathcount">
            <xsl:value-of select="count(paths/path)"/>
          </xsl:variable>
          <xsl:if test="$pathcount &gt; 0">
            <xsl:element name="span">
              <xsl:attribute name="class">revstat</xsl:attribute>
              <xsl:element name="span">
                <xsl:attribute name="class">revstatdetails</xsl:attribute>
                <xsl:variable name="pathcountA">
                  <xsl:value-of select="count(paths/path[@action = 'A'])"/>
                </xsl:variable>
                <xsl:if test="$pathcountA &gt; 0">
                  <xsl:text> | A:</xsl:text>
                  <xsl:value-of select="$pathcountA"/>
                </xsl:if>
                <xsl:variable name="pathcountD">
                  <xsl:value-of select="count(paths/path[@action = 'D'])"/>
                </xsl:variable>
                <xsl:if test="$pathcountD &gt; 0">
                  <xsl:text> | D:</xsl:text>
                  <xsl:value-of select="$pathcountD"/>
                </xsl:if>
                <xsl:variable name="pathcountM">
                  <xsl:value-of select="count(paths/path[@action = 'M'])"/>
                </xsl:variable>
                <xsl:if test="$pathcountM &gt; 0">
                  <xsl:text> | M:</xsl:text>
                  <xsl:value-of select="$pathcountM"/>
                </xsl:if>
                <xsl:variable name="pathcountR">
                  <xsl:value-of select="count(paths/path[@action = 'R'])"/>
                </xsl:variable>
                <xsl:if test="$pathcountR &gt; 0">
                  <xsl:text> | R:</xsl:text>
                  <xsl:value-of select="$pathcountR"/>
                </xsl:if>
                <xsl:text> |</xsl:text>
              </xsl:element>
              <xsl:text>(</xsl:text>
              <xsl:value-of select="$pathcount"/>
              <xsl:text> item</xsl:text>
              <xsl:if test="$pathcount &gt; 1">
                <xsl:text>s</xsl:text>
              </xsl:if>
              <xsl:text>)</xsl:text>
            </xsl:element>
          </xsl:if>
          <div class="revdate">
            <xsl:value-of select="substring-before($date,'T')"/>
            <span class="revdate">
              <xsl:text>at </xsl:text>
              <xsl:value-of select="substring-before(substring-after($date,'T'),'.')"/>
            </span>
          </div>
          <div class="logmsg"><xsl:value-of select="msg"/></div>
        </xsl:element>

        <!-- If we have any paths, use this template -->
        <xsl:apply-templates select="paths"/>
      </xsl:element>
    </xsl:element>
  </xsl:template>

  <!-- The paths entry may have one or more path entries. -->
  <!-- Here we handle each, including sorting them into   -->
  <!-- the order we like.  (Type and then filename)       -->
  <xsl:template match="paths">
    <xsl:element name="div">
      <xsl:attribute name="class">paths</xsl:attribute>
      <xsl:attribute name="id">
        <xsl:text>:</xsl:text>
        <xsl:value-of select="../@revision"/>
      </xsl:attribute>
      <xsl:attribute name="style">display: none;</xsl:attribute>
      <xsl:for-each select="path">
        <xsl:sort select="@action"/>
        <xsl:sort select="."/>
        <xsl:element name="div">
          <xsl:attribute name="class">pathline</xsl:attribute>
          <xsl:attribute name="onclick">
            <xsl:text>detailClick('</xsl:text>
            <xsl:value-of select="../../../@repository"/>
            <xsl:text>','</xsl:text>
            <xsl:value-of select="@action"/>
            <xsl:text>','</xsl:text>
            <xsl:value-of select="."/>
            <xsl:text>','</xsl:text>
            <xsl:value-of select="../../@revision"/>
            <xsl:text>','</xsl:text>
            <xsl:value-of select="../../../logentry[1]/@revision"/>
            <xsl:text>');</xsl:text>
          </xsl:attribute>
          <xsl:element name="div">
            <xsl:attribute name="class">pathaction</xsl:attribute>
            <xsl:value-of select="@action"/>
          </xsl:element>
          <xsl:element name="div">
            <xsl:attribute name="class">pathfile</xsl:attribute>
            <xsl:value-of select="."/>
            <br/>
            <xsl:element name="div">
              <xsl:attribute name="class">pathpopup</xsl:attribute>
              <xsl:attribute name="onmouseover">onPopup(this);</xsl:attribute>
              <xsl:attribute name="onmouseout">offPopup(this);</xsl:attribute>
              <xsl:attribute name="id">
                <xsl:value-of select="."/>
                <xsl:text>:</xsl:text>
                <xsl:value-of select="../../@revision"/>
              </xsl:attribute>
            </xsl:element>
          </xsl:element>
        </xsl:element>
      </xsl:for-each>
    </xsl:element>
    <xsl:element name="script">
      <xsl:attribute name="type">text/javascript</xsl:attribute>
      <xsl:attribute name="language">JavaScript</xsl:attribute>
      <xsl:text>addDetail(</xsl:text>
      <xsl:value-of select="../@revision"/>
      <xsl:text>);</xsl:text>
    </xsl:element>
  </xsl:template>

</xsl:stylesheet>

