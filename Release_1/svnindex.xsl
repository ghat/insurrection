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
        <!-- Some hidden images for the Javascript to access by Id -->
        <xsl:element name="img">
          <xsl:attribute name="src">
            <xsl:value-of select="document('insurrection.xml')/xml/images/closedicon/@src"/>
          </xsl:attribute>
          <xsl:attribute name="id">closedImage</xsl:attribute>
          <xsl:attribute name="style">display: none</xsl:attribute>
        </xsl:element>
        <xsl:element name="img">
          <xsl:attribute name="src">
            <xsl:value-of select="document('insurrection.xml')/xml/images/openedicon/@src"/>
          </xsl:attribute>
          <xsl:attribute name="id">openedImage</xsl:attribute>
          <xsl:attribute name="style">display: none</xsl:attribute>
        </xsl:element>
        <xsl:element name="img">
          <xsl:attribute name="src">
            <xsl:value-of select="document('insurrection.xml')/xml/images/diricon/@src"/>
          </xsl:attribute>
          <xsl:attribute name="id">dirImage</xsl:attribute>
          <xsl:attribute name="style">display: none</xsl:attribute>
        </xsl:element>
        <xsl:element name="img">
          <xsl:attribute name="src">
            <xsl:value-of select="document('insurrection.xml')/xml/images/fileicon/@src"/>
          </xsl:attribute>
          <xsl:attribute name="id">fileImage</xsl:attribute>
          <xsl:attribute name="style">display: none</xsl:attribute>
        </xsl:element>
        <xsl:element name="img">
          <xsl:attribute name="src">
            <xsl:value-of select="document('insurrection.xml')/xml/images/infoicon/@src"/>
          </xsl:attribute>
          <xsl:attribute name="id">infoImage</xsl:attribute>
          <xsl:attribute name="style">display: none</xsl:attribute>
        </xsl:element>
        <xsl:element name="img">
          <xsl:attribute name="src">
            <xsl:value-of select="document('insurrection.xml')/xml/images/blankicon/@src"/>
          </xsl:attribute>
          <xsl:attribute name="id">blankImage</xsl:attribute>
          <xsl:attribute name="style">display: none</xsl:attribute>
        </xsl:element>

        <!-- Now for the real page... -->
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
    <div class="svn">
    <table width="100%" cellpadding="0" cellspacing="0" border="0">
      <xsl:apply-templates select="updir"/>
      <tr class="pathrow">
        <td class="foldspace">
          <xsl:element name="img">
            <xsl:attribute name="align">middle</xsl:attribute>
            <xsl:attribute name="alt">An opened directory</xsl:attribute>
            <xsl:attribute name="src">
              <xsl:value-of select="document('insurrection.xml')/xml/images/openedicon/@src"/>
            </xsl:attribute>
          </xsl:element>
        </td>
        <td class="path">
          <xsl:element name="img">
            <xsl:attribute name="class">svnentryicon</xsl:attribute>
            <xsl:attribute name="align">middle</xsl:attribute>
            <xsl:attribute name="alt">A directory</xsl:attribute>
            <xsl:attribute name="src">
              <xsl:value-of select="document('insurrection.xml')/xml/images/diricon/@src"/>
            </xsl:attribute>
          </xsl:element>
          <xsl:value-of select="@path"/>
        </td>
        <td class="rev">
          <xsl:if test="string-length(@name) != 0">
            <xsl:value-of select="@name"/>
          </xsl:if>
          <xsl:if test="string-length(@rev) = 0">
            <xsl:text>&#8212; </xsl:text>
          </xsl:if>
          <xsl:if test="string-length(@rev) != 0">
            <xsl:text>Revision </xsl:text>
            <xsl:value-of select="@rev"/>
          </xsl:if>
        </td>
        <td class="showlog">
          <xsl:element name="a">
            <xsl:attribute name="onmouseover">
              <xsl:text>logLink(this,'.');</xsl:text>
            </xsl:attribute>
            <xsl:element name="img">
              <xsl:attribute name="align">middle</xsl:attribute>
              <xsl:attribute name="alt">Get revision history</xsl:attribute>
              <xsl:attribute name="src">
                <xsl:value-of select="document('insurrection.xml')/xml/images/infoicon/@src"/>
              </xsl:attribute>
            </xsl:element>
          </xsl:element>
        </td>
      </tr>
      <tr>
        <td>
          <xsl:element name="img">
            <xsl:attribute name="align">middle</xsl:attribute>
            <xsl:attribute name="alt">A file spacer</xsl:attribute>
            <xsl:attribute name="src">
              <xsl:value-of select="document('insurrection.xml')/xml/images/blankicon/@src"/>
            </xsl:attribute>
          </xsl:element>
        </td>
        <td colspan="3">
          <table width="100%" cellpadding="0" cellspacing="0" border="0">
            <xsl:apply-templates select="dir"/>
            <xsl:apply-templates select="file"/>
          </table>
        </td>
      </tr>
    </table>
    </div>
  </xsl:template>

  <xsl:template match="updir">
    <tr class="updirrow">
      <td colspan="4">
        <xsl:element name="a">
          <xsl:attribute name="href">..</xsl:attribute>
          <div class="updir">
            <xsl:element name="img">
              <xsl:attribute name="class">svnentryicon</xsl:attribute>
              <xsl:attribute name="align">middle</xsl:attribute>
              <xsl:attribute name="alt">A directory</xsl:attribute>
              <xsl:attribute name="src">
                <xsl:value-of select="document('insurrection.xml')/xml/images/diricon/@src"/>
              </xsl:attribute>
            </xsl:element>
            <xsl:text>.. (Parent Directory)</xsl:text>
          </div>
        </xsl:element>
      </td>
    </tr>
  </xsl:template>

  <xsl:template match="dir">
    <tr class="dirrow">
      <td class="foldspace">
        <xsl:element name="img">
          <xsl:attribute name="class">dirarrow</xsl:attribute>
          <xsl:attribute name="align">middle</xsl:attribute>
          <xsl:attribute name="alt">A closed directory</xsl:attribute>
          <xsl:attribute name="src">
            <xsl:value-of select="document('insurrection.xml')/xml/images/closedicon/@src"/>
          </xsl:attribute>
          <xsl:attribute name="onclick">loadDir(this)</xsl:attribute>
          <xsl:attribute name="id">
            <xsl:text>/</xsl:text>
            <xsl:value-of select="@href"/>
          </xsl:attribute>
        </xsl:element>
      </td>
      <td>
        <xsl:element name="a">
          <xsl:attribute name="href">
            <xsl:value-of select="@href"/>
          </xsl:attribute>
          <div class="dir">
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
      </td>
      <td class="showlog">
        <xsl:element name="a">
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
      </td>
    </tr>
    <!-- The hidden row for expanding the directory "in place" -->
    <xsl:element name="tr">
      <xsl:attribute name="style">display: none</xsl:attribute>
      <xsl:attribute name="id">
        <xsl:text>./</xsl:text>
        <xsl:value-of select="@href"/>
        <xsl:text>_</xsl:text>
      </xsl:attribute>
      <td class="foldspace">
        <xsl:element name="img">
          <xsl:attribute name="align">middle</xsl:attribute>
          <xsl:attribute name="alt">A subdir spacer</xsl:attribute>
          <xsl:attribute name="src">
            <xsl:value-of select="document('insurrection.xml')/xml/images/blankicon/@src"/>
          </xsl:attribute>
        </xsl:element>
      </td>
      <xsl:element name="td">
        <xsl:attribute name="colspan">2</xsl:attribute>
        <xsl:attribute name="id">
          <xsl:text>./</xsl:text>
          <xsl:value-of select="@href"/>
        </xsl:attribute>
      </xsl:element>
    </xsl:element>
  </xsl:template>

  <xsl:template match="file">
    <tr class="filerow">
      <td class="foldspace">
        <xsl:element name="img">
          <xsl:attribute name="align">middle</xsl:attribute>
          <xsl:attribute name="alt">A file spacer</xsl:attribute>
          <xsl:attribute name="src">
            <xsl:value-of select="document('insurrection.xml')/xml/images/blankicon/@src"/>
          </xsl:attribute>
        </xsl:element>
      </td>
      <td>
        <xsl:element name="a">
          <xsl:attribute name="href">
            <xsl:value-of select="@href"/>
          </xsl:attribute>
          <div class="file">
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
      </td>
      <td class="showlog">
        <xsl:element name="a">
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
      </td>
    </tr>
  </xsl:template>

</xsl:stylesheet>
