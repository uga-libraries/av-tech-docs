<xsl:stylesheet
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0"
    xpath-default-namespace="http://www.pbcore.org/PBCore/PBCoreNamespace.html"
    exclude-result-prefixes="xs">
    <!--without output and strip-space, get blank lines in xml where remove elements-->
    <xsl:output method="xml" indent="yes"/>
    <xsl:strip-space elements="*"/>

<!--Copies all elements and attributes, unless there are more specific instructions in other templates-->
<xsl:template match="@*|node()">
    <xsl:copy>
        <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
</xsl:template>

<!--Will not copy any of these elements-->
<xsl:template match="instantiationIdentifier[@source='SegmentUID']" />
<xsl:template match="instantiationIdentifier[@source='UMID']" />
<xsl:template match="instantiationIdentifier[@source='com.apple.finalcutstudio.media.uuid']" />
<xsl:template match="instantiationAnnotation" />
<xsl:template match="instantiationEssenceTrack/essenceTrackIdentifier[@source='UniqueID']" />
<xsl:template match="instantiationEssenceTrack/essenceTrackIdentifier[@source='StreamKindID (MediaInfo)']" />
<xsl:template match="instantiationEssenceTrack/essenceTrackIdentifier[@source='StreamOrder (MediaInfo)']" />


<!--Select instantiationIdentifier source="File Name" to make collection ID-->
<!--But also keep a copy of the instantiationIdentifier-->
<xsl:template match="instantiationIdentifier[@source='File Name']">
	<pbcoreCollection>
	    <xsl:choose>
	    <xsl:when test="matches(., '^\d{5,6}')">
	        <xsl:text>peabody</xsl:text>
	    </xsl:when>
	    <xsl:otherwise>
	        <xsl:analyze-string select="." regex="([\w_-]+)_">
	            <xsl:matching-substring><xsl:value-of select="regex-group(1)"/></xsl:matching-substring>
	        </xsl:analyze-string>
	    </xsl:otherwise>
	    </xsl:choose>
	</pbcoreCollection>
    <!--if I wanted to keep the instantiationIdentifier field as is from original XML, include this
	<xsl:copy-of select="."/>
    -->


<!-- Stores item ID as variable and then adds to ARCHive URI prefix-->
    <!-- regex to get the filename without the extension for CA matching -->
        <xsl:variable name="item-id">
            <xsl:analyze-string select="." regex="(.+)\.\w{{3}}">
            <xsl:matching-substring><xsl:value-of select="regex-group(1)" /></xsl:matching-substring>
             </xsl:analyze-string>
         </xsl:variable>

    <!-- Storing filename as a variable-->
        <xsl:variable
          name="filename"
          select=".">
        </xsl:variable>

    <!--Creating instantiationIdentifer from item-id variable -->
    <instantiationIdentifier>
        <xsl:value-of select="$item-id"/>
        <xsl:text>_digipres-master</xsl:text>
    </instantiationIdentifier>



 <!-- Uses variable item-id to populate related Instantiationfield -->
    <relatedInstantiation>
        <xsl:value-of select="$item-id"/>
    </relatedInstantiation>

 <!-- Uses variable item-id to populate related Instantiationfield -->
    <instantiationDPHub>
        <xsl:text>/Volumes/mezzanine_4/</xsl:text>
        <xsl:value-of select="$filename"/>
    </instantiationDPHub>
<!-- Sets Generation type -->
    <instantiationGeneration>
        <xsl:text>digitalPreservationMaster</xsl:text>
    </instantiationGeneration>
 <!-- Sets Creator to BMA -->
    <instantiationCreator>
        <xsl:text>brownMediaArchives</xsl:text>
    </instantiationCreator>   

</xsl:template>



    <xsl:template match="instantiationEssenceTrack/essenceTrackAnnotation[@annotationType='ColorSpace']">
            <essenceTrackColorSpace><xsl:value-of select="."/></essenceTrackColorSpace>
    </xsl:template>


<!-- formats file type ID to something more palatable for CA -->
<!-- taking this out bc pbcore standard suggests using mime type -->

 <xsl:template match="instantiationDigital">
        <xsl:choose>
            <xsl:when test=". = 'video/mp4' or . = 'video/quicktime'">
                <instantiationDigital>quicktime</instantiationDigital>
            </xsl:when>
        </xsl:choose>
</xsl:template>



</xsl:stylesheet>
