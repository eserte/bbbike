<?xml version="1.0"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:template match="ttqv">
    <gpx xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	 xmlns="http://www.topografix.com/GPX/1/1"
	 version="1.1"
	 creator="ttqv2gpx.xsl - http://www.bbbike.de"
	 xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
      <xsl:apply-templates />
    </gpx>
  </xsl:template>

  <xsl:template match="track">
    <trk>
      <name><xsl:value-of select="./name" /></name>
      <trkseg>
	<xsl:apply-templates />
      </trkseg>
    </trk>
  </xsl:template>

  <xsl:template match="trp">
    <trkpt>
      <xsl:attribute name="lat">
	<xsl:value-of select="./lat" />
      </xsl:attribute>
      <xsl:attribute name="lon">
	<xsl:value-of select="./lon" />
      </xsl:attribute>
    </trkpt>
  </xsl:template>

  <xsl:template match="text()">
  </xsl:template>

</xsl:stylesheet>
