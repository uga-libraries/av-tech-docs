<!--
- XSL to create XML for importing digital object records into Collective Access
- XSL works on mediainfo XML, generated with the flags: Output=PBCore2 Language=raw
- This XSL is meant to be run via transform-pbcore-to-ca-xml.sh, which passes variables to this script
-->


<xsl:stylesheet
    xmlns="http://www.pbcore.org/PBCore/PBCoreNamespace.html"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    version="2.0"
    xpath-default-namespace="http://www.pbcore.org/PBCore/PBCoreNamespace.html"
    exclude-result-prefixes="xs">

<xsl:output method="xml" indent="yes"/>
<xsl:strip-space elements="*"/>

<xsl:param name="creator" select="'brownMediaArchives'"/>
<xsl:param name="generation" select="'digitalPreservationMaster'"/>
<xsl:param name="mezzanine_share" select="''"/>

<xsl:template match="@*|node()">
   <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
   </xsl:copy>
</xsl:template>

<xsl:template match="/">
   <xsl:apply-templates/>
</xsl:template>

<xsl:template match="instantiationIdentifier[@source='SegmentUID']"/>
<xsl:template match="instantiationIdentifier[@source='UMID']"/>
<xsl:template match="instantiationIdentifier[@source='com.apple.finalcutstudio.media.uuid']"/>
<xsl:template match="instantiationIdentifier[@source='File Name']"/>

<xsl:template match="instantiationAnnotation"/>
<xsl:template match="instantiationEssenceTrack/essenceTrackIdentifier[@source='UniqueID']"/>
<xsl:template match="instantiationEssenceTrack/essenceTrackIdentifier[@source='StreamKindID (MediaInfo)']"/>
<xsl:template match="instantiationEssenceTrack/essenceTrackIdentifier[@source='StreamOrder (MediaInfo)']"/>

<xsl:template match="pbcoreInstantiationDocument">

  <pbcoreInstantiationDocument>
    <xsl:apply-templates select="@*"/>

    <xsl:variable name="filename"
        select="replace(instantiationIdentifier[@source='File Name'],'^.*/','')"/>

    <xsl:variable name="item-id"
        select="replace($filename,'^(bmac_)?(.+)\.\w+$','$2')"/>

    <xsl:variable name="base-id"
        select="replace($item-id,'_\d{2}$','')"/>

    <xsl:variable name="is-peabody"
        select="matches($filename,'^(bmac_)?\d{4,}')"/>

    <pbcoreCollection>
      <xsl:choose>
        <xsl:when test="$is-peabody">peabody</xsl:when>
        <xsl:otherwise>
            <xsl:value-of select="replace($item-id,'^([^_]+).*','$1')"/>
        </xsl:otherwise>
      </xsl:choose>
    </pbcoreCollection>

    <instantiationIdentifier>
        <xsl:if test="$is-peabody">peabody_</xsl:if>
        <xsl:value-of select="$item-id"/>

        <xsl:choose>
            <xsl:when test="$generation='mezzanine'">
                <xsl:text>_video-mezz</xsl:text>
             </xsl:when>
            <xsl:when test="$generation='archivalOriginal'">
                </xsl:when>
            <xsl:otherwise>
                 <xsl:text>_digipres-master</xsl:text>
             </xsl:otherwise>
         </xsl:choose>
    </instantiationIdentifier>

    <xsl:if test="$generation='digitalPreservationMaster' or $generation='archivalOriginal'">
        <ARCHiveURI>
            <xsl:text>http://archive.libs.uga.edu/bmac/bmac_</xsl:text>
            <xsl:value-of select="$item-id"/>
        </ARCHiveURI>
    </xsl:if>

    <xsl:if test="$generation != 'archivalOriginal'">
        <relatedInstantiation>
          <xsl:if test="$is-peabody">peabody_</xsl:if>
          <xsl:value-of select="$base-id"/>
        </relatedInstantiation>
    </xsl:if>

    <instantiationGeneration>
      <xsl:value-of select="$generation"/>
    </instantiationGeneration>

    <xsl:if test="$generation='mezzanine'">
        <instantiationDPHub>
            <xsl:text>/Volumes/</xsl:text>
            <xsl:value-of select="$mezzanine_share"/>
            <xsl:text>/</xsl:text>
            <xsl:value-of select="$filename"/>
       </instantiationDPHub>
    </xsl:if>

    <instantiationCreator>
      <xsl:value-of select="$creator"/>
    </instantiationCreator>

    <xsl:apply-templates select="node()"/>

  </pbcoreInstantiationDocument>

</xsl:template>

</xsl:stylesheet>
