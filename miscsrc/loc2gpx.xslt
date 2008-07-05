<?xml version="1.0"?>
<!--
Converts the geocaching.com loc format into gpx.

Possible usage:

   xlstproc loc2gpx.xslt geocaching.loc | ./gpx2bbd -

-->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:template match="loc">
    <gpx xmlns="http://www.topografix.com/GPX/1/1" creator="loc2gpx.xslt" version="1.1" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
      <xsl:apply-templates />
    </gpx>
  </xsl:template>

  <xsl:template match="waypoint">
    <wpt>
      <xsl:attribute name="lat">
	<xsl:value-of select="./coord/@lat" />
      </xsl:attribute>
      <xsl:attribute name="lon">
	<xsl:value-of select="./coord/@lon" />
      </xsl:attribute>
      <name>
	<xsl:value-of select="./name/@id" />
      </name>
    </wpt>
  </xsl:template>

</xsl:stylesheet>
