<?xml version="1.0"?>
<!-- $Id$ -->
<!-- Copyright 2004,2005 - Michael Sinz -->
<!-- This is my magic Subversion index XSLT transform to HTML -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

  <xsl:output method="html"/>

  <xsl:template match="*"/>

  <!-- ******************************************************************************************************************* -->
  <!-- This is the template for the SVN index browsing -->
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

  <xsl:template match="updir">
    <tr class="updirrow">
      <td colspan="4">
        <xsl:element name="a">
          <xsl:attribute name="href">..</xsl:attribute>
          <div class="updir">
            <xsl:element name="img">
              <xsl:attribute name="class">svnentryicon</xsl:attribute>
              <xsl:attribute name="align">middle</xsl:attribute>
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

  <xsl:template match="index">
    <div class="svn">
    <table width="100%" cellpadding="0" cellspacing="0" border="0">
      <xsl:apply-templates select="updir"/>
      <tr class="pathrow">
        <td class="foldspace">
          <xsl:element name="img">
            <xsl:attribute name="class">dirarrow</xsl:attribute>
            <xsl:attribute name="align">middle</xsl:attribute>
            <xsl:attribute name="onclick">foldDir(this)</xsl:attribute>
            <xsl:attribute name="id">
              <xsl:text>/</xsl:text>
            </xsl:attribute>
            <xsl:attribute name="src">
              <xsl:value-of select="document('insurrection.xml')/xml/images/openedicon/@src"/>
            </xsl:attribute>
          </xsl:element>
        </td>
        <td class="path">
          <xsl:element name="img">
            <xsl:attribute name="class">svnentryicon</xsl:attribute>
            <xsl:attribute name="align">middle</xsl:attribute>
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
      <tr id="./_">
        <td>
          <xsl:element name="img">
            <xsl:attribute name="align">middle</xsl:attribute>
            <xsl:attribute name="src">
              <xsl:value-of select="document('insurrection.xml')/xml/images/blankicon/@src"/>
            </xsl:attribute>
          </xsl:element>
        </td>
        <td colspan="3" id="./">
          <table width="100%" cellpadding="0" cellspacing="0" border="0">
            <xsl:apply-templates select="dir"/>
            <xsl:apply-templates select="file"/>
          </table>
        </td>
      </tr>
    </table>
    </div>
  </xsl:template>

  <xsl:template match="dir">
    <tr class="dirrow">
      <td class="foldspace">
        <xsl:element name="img">
          <xsl:attribute name="class">dirarrow</xsl:attribute>
          <xsl:attribute name="align">middle</xsl:attribute>
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

  <!-- ******************************************************************************************************************* -->
  <!-- This is the template for the SVN log output -->
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
                      <xsl:text>Change log of revision</xsl:text>
                      <xsl:if test="count(logentry) != 1">
                        <xsl:text>s</xsl:text>
                      </xsl:if>
                      <xsl:text> </xsl:text>
                      <xsl:value-of select="logentry/@revision"/>
                      <xsl:if test="count(logentry) != 1">
                        <xsl:text> through </xsl:text>
                        <xsl:value-of select="logentry[last()]/@revision"/>
                      </xsl:if>
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
          <div class="logmsg">
            <xsl:call-template name="lf2br">
                <xsl:with-param name="StringToTransform" select="msg"/>
            </xsl:call-template>
          </div>
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
            <xsl:call-template name="url-encode">
              <xsl:with-param name="str" select="."/>
            </xsl:call-template>
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
                <xsl:call-template name="url-encode">
                  <xsl:with-param name="str" select="."/>
                </xsl:call-template>
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

  <!-- template converts LF to <br/> - very useful for the log output -->
  <xsl:template name="lf2br">
      <xsl:param name="StringToTransform"/>
      <xsl:choose>
          <!-- string contains linefeed -->
          <xsl:when test="contains($StringToTransform,'&#xA;')">
              <xsl:value-of select="substring-before($StringToTransform,'&#xA;')"/>
              <br/>
              <xsl:call-template name="lf2br">
                  <xsl:with-param name="StringToTransform">
                      <xsl:value-of select="substring-after($StringToTransform,'&#xA;')"/>
                  </xsl:with-param>
              </xsl:call-template>
          </xsl:when>
          <!-- string does not contain newline, so just output it -->
          <xsl:otherwise>
              <xsl:value-of select="$StringToTransform"/>
          </xsl:otherwise>
      </xsl:choose>
  </xsl:template>

  <!-- A URL Encoding trick - makes %xx encodings of non-safe characters -->
  <!-- Note that this currently only does byte characters from 32 - 255. -->
  <xsl:variable name="chars">&#032;&#033;&#034;&#035;&#036;&#037;&#038;&#039;&#040;&#041;&#042;&#043;&#044;&#045;&#046;&#047;&#048;&#049;&#050;&#051;&#052;&#053;&#054;&#055;&#056;&#057;&#058;&#059;&#060;&#061;&#062;&#063;&#064;&#065;&#066;&#067;&#068;&#069;&#070;&#071;&#072;&#073;&#074;&#075;&#076;&#077;&#078;&#079;&#080;&#081;&#082;&#083;&#084;&#085;&#086;&#087;&#088;&#089;&#090;&#091;&#092;&#093;&#094;&#095;&#096;&#097;&#098;&#099;&#100;&#101;&#102;&#103;&#104;&#105;&#106;&#107;&#108;&#109;&#110;&#111;&#112;&#113;&#114;&#115;&#116;&#117;&#118;&#119;&#120;&#121;&#122;&#123;&#124;&#125;&#126;&#127;&#128;&#129;&#130;&#131;&#132;&#133;&#134;&#135;&#136;&#137;&#138;&#139;&#140;&#141;&#142;&#143;&#144;&#145;&#146;&#147;&#148;&#149;&#150;&#151;&#152;&#153;&#154;&#155;&#156;&#157;&#158;&#159;&#160;&#161;&#162;&#163;&#164;&#165;&#166;&#167;&#168;&#169;&#170;&#171;&#172;&#173;&#174;&#175;&#176;&#177;&#178;&#179;&#180;&#181;&#182;&#183;&#184;&#185;&#186;&#187;&#188;&#189;&#190;&#191;&#192;&#193;&#194;&#195;&#196;&#197;&#198;&#199;&#200;&#201;&#202;&#203;&#204;&#205;&#206;&#207;&#208;&#209;&#210;&#211;&#212;&#213;&#214;&#215;&#216;&#217;&#218;&#219;&#220;&#221;&#222;&#223;&#224;&#225;&#226;&#227;&#228;&#229;&#230;&#231;&#232;&#233;&#234;&#235;&#236;&#237;&#238;&#239;&#240;&#241;&#242;&#243;&#244;&#245;&#246;&#247;&#248;&#249;&#250;&#251;&#252;&#253;&#254;&#255;</xsl:variable>

  <!-- Hex characters we will use -->
  <xsl:variable name="hex">0123456789ABCDEF</xsl:variable>

  <!-- Characters that usually don't need to be escaped -->
  <xsl:variable name="safe">/-.0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz</xsl:variable>

  <xsl:template name="url-encode">
    <xsl:param name="str"/>
    <xsl:if test="$str">
      <xsl:variable name="firstchar" select="substring($str,1,1)"/>
      <xsl:choose>
        <xsl:when test="contains($safe,$firstchar)">
          <xsl:value-of select="$firstchar"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:variable name="encodechar">
            <xsl:choose>
              <xsl:when test="contains($chars,$firstchar)">
                <xsl:value-of select="string-length(substring-before($chars,$firstchar)) + 32"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:message terminate="no">Warning: string contains a character that is out of range! Substituting "&#127;".</xsl:message>
                <xsl:text>127</xsl:text>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:variable>
        <xsl:variable name="hex-digit1" select="substring($hex,floor($encodechar div 16) + 1,1)"/>
        <xsl:variable name="hex-digit2" select="substring($hex,$encodechar mod 16 + 1,1)"/>
        <xsl:value-of select="concat('%',$hex-digit1,$hex-digit2)"/>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:if test="string-length($str) &gt; 1">
        <xsl:call-template name="url-encode">
          <xsl:with-param name="str" select="substring($str,2)"/>
        </xsl:call-template>
      </xsl:if>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>
