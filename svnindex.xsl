<?xml version="1.0"?>
<!-- $Id$ -->
<!-- Copyright 2004,2005 - Michael Sinz -->
<!-- This is my magic Subversion index XSLT transform to HTML -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

  <xsl:output method="html"/>

  <xsl:template match="*"/>

  <xsl:template match="svn">
    <html>
      <head>
        <title>
          <xsl:if test="string-length(index/@name) != 0">
            <xsl:value-of select="index/@name"/>
            <xsl:text>: </xsl:text>
          </xsl:if>
          <xsl:value-of select="index/@path"/>
        </title>
        <xsl:copy-of select="document('insurrection.xml')/xml/header/*"/>
      </head>
      <body>
        <table id="pagetable">
          <tr>
            <td id="content">
              <xsl:copy-of select="document('insurrection.xml')/xml/banner/*"/>

              <!-- If there is a local banner defined, have the JS load it -->
              <xsl:if test="index/file[@href = '.svn_index']">
                <xsl:element name="div">
                  <xsl:attribute name="id">localbanner</xsl:attribute>
                </xsl:element>
                <xsl:element name="script">
                  <xsl:attribute name="type">text/javascript</xsl:attribute>
                  <xsl:attribute name="language">JavaScript</xsl:attribute>
                  <xsl:text>loadBanner('.svn_index');</xsl:text>
                </xsl:element>
              </xsl:if>

              <xsl:apply-templates/>

              <div class="footer">
                <xsl:text>Powered by Subversion </xsl:text>
                <xsl:value-of select="@version"/>
                <xsl:text> -- $Id$</xsl:text>
              </div>
            </td>
          </tr>
        </table>
      </body>
    </html>
  </xsl:template>

  <xsl:template match="index">
    <table class="svn" width="100%" cellpadding="0" cellspacing="0" border="0">
      <tr class="path">
        <td class="path">
          <xsl:value-of select="@path"/>
        </td>
        <td class="rev">
          <xsl:if test="string-length(@name) != 0">
            <xsl:value-of select="@name"/>
            <xsl:if test="string-length(@rev) != 0">
              <xsl:text>&#8212; </xsl:text>
            </xsl:if>
          </xsl:if>
          <xsl:if test="string-length(@rev) != 0">
            <xsl:text>Revision </xsl:text>
            <xsl:value-of select="@rev"/>
          </xsl:if>
        </td>
      </tr>
      <tr>
        <td colspan="2">
          <xsl:apply-templates select="updir"/>
          <xsl:apply-templates select="dir"/>
          <xsl:apply-templates select="file"/>
        </td>
      </tr>
    </table>
  </xsl:template>

  <xsl:template match="updir">
    <xsl:element name="a">
      <xsl:attribute name="href">..</xsl:attribute>
      <div class="updir">
        <xsl:text>.. (Parent Directory)</xsl:text>
      </div>
    </xsl:element>
  </xsl:template>

  <xsl:template match="dir">
    <div class="svnentry">
      <xsl:element name="a">
        <xsl:attribute name="class">showlog</xsl:attribute>
        <xsl:attribute name="onmouseover">
          <xsl:text>logLink(this,'</xsl:text>
          <xsl:value-of select="@href"/>
          <xsl:text>');</xsl:text>
        </xsl:attribute>
        <xsl:element name="img">
          <xsl:attribute name="align">middle</xsl:attribute>
          <xsl:attribute name="alt">Get revision history</xsl:attribute>
          <xsl:attribute name="src">
            <xsl:value-of select="document('insurrection.xml')/xml/images/infoicon/@src"/>
          </xsl:attribute>
        </xsl:element>
      </xsl:element>
      <xsl:element name="a">
        <xsl:attribute name="href">
          <xsl:value-of select="@href"/>
        </xsl:attribute>
        <div class="dir">
          <xsl:element name="img">
            <xsl:attribute name="align">middle</xsl:attribute>
            <xsl:attribute name="alt">A closed directory</xsl:attribute>
            <xsl:attribute name="src">
              <xsl:value-of select="document('insurrection.xml')/xml/images/closedicon/@src"/>
            </xsl:attribute>
          </xsl:element>
          <xsl:element name="img">
            <xsl:attribute name="class">svnentryicon</xsl:attribute>
            <xsl:attribute name="align">middle</xsl:attribute>
            <xsl:attribute name="alt">A directory</xsl:attribute>
            <xsl:attribute name="src">
              <xsl:value-of select="document('insurrection.xml')/xml/images/diricon/@src"/>
            </xsl:attribute>
          </xsl:element>
          <xsl:value-of select="@name"/>
          <xsl:text>/</xsl:text>
        </div>
      </xsl:element>
    </div>
  </xsl:template>

  <xsl:template match="file">
    <div class="svnentry">
      <xsl:element name="a">
        <xsl:attribute name="class">showlog</xsl:attribute>
        <xsl:attribute name="onmouseover">
          <xsl:text>logLink(this,'</xsl:text>
          <xsl:value-of select="@href"/>
          <xsl:text>');</xsl:text>
        </xsl:attribute>
        <xsl:element name="img">
          <xsl:attribute name="align">middle</xsl:attribute>
          <xsl:attribute name="alt">Get revision history</xsl:attribute>
          <xsl:attribute name="src">
            <xsl:value-of select="document('insurrection.xml')/xml/images/infoicon/@src"/>
          </xsl:attribute>
        </xsl:element>
      </xsl:element>
      <xsl:element name="a">
        <xsl:attribute name="href">
          <xsl:value-of select="@href"/>
        </xsl:attribute>
        <div class="file">
          <xsl:element name="img">
            <xsl:attribute name="align">middle</xsl:attribute>
            <xsl:attribute name="alt">A file spacer</xsl:attribute>
            <xsl:attribute name="src">
              <xsl:value-of select="document('insurrection.xml')/xml/images/blankicon/@src"/>
            </xsl:attribute>
          </xsl:element>
          <xsl:element name="img">
            <xsl:attribute name="class">svnentryicon</xsl:attribute>
            <xsl:attribute name="align">middle</xsl:attribute>
            <xsl:attribute name="alt">A file</xsl:attribute>
            <xsl:attribute name="src">
              <xsl:value-of select="document('insurrection.xml')/xml/images/fileicon/@src"/>
            </xsl:attribute>
          </xsl:element>
          <xsl:value-of select="@name"/>
        </div>
      </xsl:element>
    </div>
  </xsl:template>

</xsl:stylesheet>
