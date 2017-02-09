<?xml version="1.0" encoding="UTF-8"?>
<!-- **********************************************************************
 * (C) 2014 - GFZ-Potsdam
 *
 * SC3ML 0.7 to QuakeML 1.2 stylesheet converter
 * Author  : Stephan Herrnkind
 * Email   : stephan.herrnkind@gempa.de
 * Version : 2014.251.01
 *
 * ================
 * Usage
 * ================
 *
 * This stylesheet converts a SC3ML to a QuakeML document. It may be invoked
 * e.g. using xalan or xsltproc:
 *
 *   xalan -in sc3ml.xml -xsl sc3ml_0.7__quakeml_1.2.xsl -out quakeml.xml
 *   xsltproc -o quakeml.xml sc3ml_0.7__quakeml_1.2.xsl sc3ml.xml
 *
 * ================
 * Transformation
 * ================
 *
 * QuakeML and SC3ML are quite similar schemas. Nevertheless some differences
 * exist:
 *
 *  - IDs : SC3ML does not enforce any particular ID restriction. An ID in
 *    SC3ML has no semantic, it simply must be unique. Hence QuakeML uses ID
 *    restrictions, a conversion of a SC3ML to a QuakeML ID must be performed:
 *    'sc3id' -> 'smi:scs/0.7/sc3id'. If no SC3ML ID is available but QuakeML
 *    enforces one, a static ID value of 'NA' is used.
 *  - Repositioning of nodes: In QuakeML all information is grouped under the
 *    event element. As a consequence every node not referenced by an event
 *    will be lost during the conversion.
 *
 *    <EventParameters>               <eventParameters>
 *                                        <event>
 *        <pick/>                             <pick/>
 *        <amplitude/>                        <amplitude/>
 *        <reading/>
 *        <origin>                            <origin/>
 *            <stationMagnitude/>             <stationMagnitude/>
 *            <magnitude/>                    <magnitude/>
 *        </origin>
 *        <focalMechanism/>                   <focalMechanism/>
 *        <event/>                        </event>
 *    </EventParameters>              </eventParameters>
 *
 *  - Renaming of nodes: The following table lists the mapping of names between
 *    both schema:
 *
 *    Parent (SC3)        SC3 name           QuakeML name
 *    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""
 *    seiscomp            EventParameters    eventParameters
 *    arrival             weight             timeWeight
 *                        takeOffAngle       takeoffAngle
 *    magnitude           magnitude          mag
 *    stationMagnitude    magnitude          mag
 *    amplitude           amplitude          genericAmplitude
 *    origin              uncertainty        originUncertainty
 *    waveformID          resourceURI        CDATA
 *    comment             id                 id (attribute)
 *
 *  - Enumerations: Both schema use enumerations. Numerous mappings are applied.
 *
 *  - Unit conversion: SC3ML uses kilometer for origin depth, QuakeML uses meter
 *
 *  - Unmapped nodes: The following nodes can not be mapped to the QuakeML
 *    schema, thus their data is lost:
 *
 *    Parent          Element lost
 *    """"""""""""""""""""""""""""""""""""""""""""""""""""""""""
 *    creationInfo    modificationTime
 *    arrival         timeUsed
 *                    horizontalSlownessUsed
 *                    backazimuthUsed
 *    focalMechanism  evaluationMode
 *                    evaluationStatus
 *    momentTensor    method
 *                    stationMomentTensorContribution
 *                    status
 *                    cmtName
 *                    cmtVersion
 *                    phaseSetting
 *    eventParameters reading
 *
 *  - Restriction of data size: QuakeML restricts string length of some
 *    elements. This length restriction is _NOT_ enforced by this
 *    stylesheet to prevent data loss. As a consequence QuakeML files
 *    generated by this XSLT may not validate because of these
 *    restrictions.
 *
 * ================
 * Change log
 * ===============
 *
 *  * 08.09.2014: Fixed typo in event type conversion (meteo[r] impact)
 *
 *  * 25.08.2014: Applied part of the patch proposed by Philipp Kaestli on
 *                seiscomp-l@gfz-potsdam.de
 *    - use public id of parent origin if origin id propertery of magnitude
 *      and station magnitude elements is unset
 *    - fixed takeOffAngle conversion vom real (SC3ML) to RealQuantity
 *      (QuakeML)
 *
 * ================
 * Licence
 * ================
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the
 * Free Software Foundation, Inc.,
 * 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 ********************************************************************** -->
<xsl:stylesheet version="1.0"
        xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
        xmlns:scs="http://geofon.gfz-potsdam.de/ns/seiscomp3-schema/0.7"
        xmlns:qml="http://quakeml.org/xmlns/quakeml/1.0"
        xmlns:q="http://quakeml.org/xmlns/quakeml/1.2"
        exclude-result-prefixes="scs qml xsl">
    <xsl:output method="xml" encoding="UTF-8" indent="no" omit-xml-declaration="yes"/>
    <xsl:strip-space elements="*"/>

    <!-- Define some global variables -->
    <!-- CHANGE ME: Please change the ID_PREFIX to the reverse DNS name of your
         institute -->
    <xsl:variable name="ID_PREFIX" select="'smi:nz.org.geonet/'"/>
    <xsl:variable name="PID" select="'publicID'"/>

    <!-- Starting point: Match the root node and select the one and only
         EventParameters node -->
    <xsl:template match="/">
        <xsl:variable name="scsRoot" select="."/>
            <xsl:for-each select="$scsRoot/scs:seiscomp/scs:EventParameters">
                    <!-- Mandatory publicID attribute -->
                    <xsl:attribute name="{$PID}">
                        <xsl:call-template name="convertOptionalID">
                            <xsl:with-param name="id" select="@publicID"/>
                        </xsl:call-template>
                    </xsl:attribute>

                    <xsl:apply-templates/>
            </xsl:for-each>
    </xsl:template>

    <!-- event -->
    <xsl:template match="scs:event">
        <xsl:element name="{local-name()}">
            <xsl:apply-templates select="@*"/>

            <!-- search origins referenced by this event -->
            <xsl:for-each select="scs:originReference">
                <xsl:for-each select="../../scs:origin[@publicID=current()]">
                    <!-- stationMagnitudes and referenced amplitudes -->
                    <xsl:for-each select="scs:stationMagnitude">
                        <xsl:for-each select="../../scs:amplitude[@publicID=current()/scs:amplitudeID]">
                            <xsl:call-template name="genericNode"/>
                        </xsl:for-each>
                        <xsl:apply-templates select="." mode="originMagnitude">
                            <xsl:with-param name="oID" select="../@publicID"/>
                        </xsl:apply-templates>
                    </xsl:for-each>

                    <!-- magnitudes -->
                    <xsl:for-each select="scs:magnitude">
                        <xsl:apply-templates select="." mode="originMagnitude">
                            <xsl:with-param name="oID" select="../@publicID"/>
                        </xsl:apply-templates>
                    </xsl:for-each>

                    <!-- picks, referenced by arrivals -->
                    <xsl:for-each select="scs:arrival">
                        <!--xsl:value-of select="scs:pickID"/-->
                        <xsl:for-each select="../../scs:pick[@publicID=current()/scs:pickID]">
                            <xsl:call-template name="genericNode"/>
                        </xsl:for-each>
                    </xsl:for-each>

                    <!-- origin -->
                    <xsl:call-template name="genericNode"/>
                </xsl:for-each>
            </xsl:for-each>

            <!-- search focalMechanisms referenced by this event -->
            <xsl:for-each select="scs:focalMechanismReference">
                <xsl:for-each select="../../scs:focalMechanism[@publicID=current()]">
                    <xsl:call-template name="genericNode"/>
                </xsl:for-each>
            </xsl:for-each>

            <xsl:apply-templates/>
        </xsl:element>
    </xsl:template>

    <!-- Default match: Map node 1:1 -->
    <xsl:template match="*">
        <xsl:call-template name="genericNode"/>
    </xsl:template>

    <!-- Delete elements -->
    <xsl:template match="scs:EventParameters/scs:pick"/>
    <xsl:template match="scs:EventParameters/scs:amplitude"/>
    <xsl:template match="scs:EventParameters/scs:reading"/>
    <xsl:template match="scs:EventParameters/scs:origin"/>
    <xsl:template match="scs:EventParameters/scs:focalMechanism"/>
    <xsl:template match="scs:event/scs:originReference|scs:focalMechanismReference"/>
    <xsl:template match="scs:event/scs:focalMechanismReference"/>
    <xsl:template match="scs:creationInfo/scs:modificationTime"/>
    <xsl:template match="scs:comment/scs:id"/>
    <xsl:template match="scs:arrival/scs:timeUsed"/>
    <xsl:template match="scs:arrival/scs:horizontalSlownessUsed"/>
    <xsl:template match="scs:arrival/scs:backazimuthUsed"/>
    <xsl:template match="scs:origin/scs:stationMagnitude"/>
    <xsl:template match="scs:origin/scs:magnitude"/>
    <xsl:template match="scs:focalMechanism/scs:evaluationMode"/>
    <xsl:template match="scs:focalMechanism/scs:evaluationStatus"/>
    <xsl:template match="scs:momentTensor/scs:method"/>
    <xsl:template match="scs:momentTensor/scs:stationMomentTensorContribution"/>
    <xsl:template match="scs:momentTensor/scs:status"/>
    <xsl:template match="scs:momentTensor/scs:cmtName"/>
    <xsl:template match="scs:momentTensor/scs:cmtVersion"/>
    <xsl:template match="scs:momentTensor/scs:phaseSetting"/>

    <!-- Converts a scs magnitude/stationMagnitude to a qml
         magnitude/stationMagnitude -->
    <xsl:template match="*" mode="originMagnitude">
        <xsl:param name="oID"/>
        <xsl:element name="{local-name()}">
            <xsl:apply-templates select="@*"/>
            <!-- if no originID element is available, create one with
                 the value of the publicID attribute of parent origin -->
            <xsl:if test="not(scs:originID)">
                <originID>
                    <xsl:call-template name="convertID">
                        <xsl:with-param name="id" select="$oID"/>
                    </xsl:call-template>
                </originID>
            </xsl:if>
            <xsl:apply-templates/>
        </xsl:element>
    </xsl:template>

    <!-- event type, enumeration differs slightly -->
    <xsl:template match="scs:event/scs:type">
        <xsl:element name="{local-name()}">
            <xsl:variable name="v" select="current()"/>
            <xsl:choose>
                <xsl:when test="$v='induced earthquake'">induced or triggered event</xsl:when>
                <xsl:when test="$v='meteor impact'">meteorite</xsl:when>
                <xsl:when test="$v='not locatable'">other</xsl:when>
                <xsl:when test="$v='outside of network interest'">other</xsl:when>
                <xsl:when test="$v='duplicate'">other</xsl:when>
                <xsl:otherwise><xsl:value-of select="$v"/></xsl:otherwise>
            </xsl:choose>
        </xsl:element>
    </xsl:template>

    <!-- origin depth, SC3ML uses kilometer, QML meter -->
    <xsl:template match="scs:origin/scs:depth/scs:value|scs:origin/scs:depth/scs:uncertainty|scs:origin/scs:depth/scs:lowerUncertainty|scs:origin/scs:depth/scs:upperUncertainty">
        <xsl:element name="{local-name()}">
            <xsl:value-of select="current() * 1000"/>
        </xsl:element>
    </xsl:template>

    <!-- evaluation status, enumeration of QML does not include 'reported' -->
    <xsl:template match="scs:origin/scs:evaluationStatus|scs:pick/scs:evaluationStatus">
        <xsl:variable name="v" select="current()"/>
        <xsl:if test="$v!='reported'">
            <xsl:element name="{local-name()}">
                <xsl:value-of select="$v"/>
            </xsl:element>
        </xsl:if>
    </xsl:template>

    <!-- data used wave type, enumeration differs slightly -->
    <xsl:template match="scs:dataUsed/scs:waveType">
        <xsl:element name="{local-name()}">
            <xsl:variable name="v" select="current()"/>
            <xsl:choose>
                <xsl:when test="$v='P body waves'">P waves</xsl:when>
                <xsl:when test="$v='long-period body waves'">body waves</xsl:when>
                <xsl:when test="$v='intermediate-period surface waves'">surface waves</xsl:when>
                <xsl:when test="$v='long-period mantle waves'">mantle waves</xsl:when>
                <xsl:otherwise><xsl:value-of select="$v"/></xsl:otherwise>
            </xsl:choose>
        </xsl:element>
    </xsl:template>

    <!-- origin uncertainty description, enumeration of QML does not include 'probability density function' -->
    <xsl:template match="scs:origin/scs:uncertainty|scs:preferredDescription">
        <xsl:variable name="v" select="current()"/>
        <xsl:if test="$v!='probability density function'">
            <xsl:element name="{local-name()}">
                <xsl:value-of select="$v"/>
            </xsl:element>
        </xsl:if>
    </xsl:template>

    <!-- origin arrival, since SC3ML does not include a publicID it is generated from pick and origin id -->
    <xsl:template match="scs:arrival">
        <xsl:element name="{local-name()}">
            <xsl:attribute name="{$PID}">
                <xsl:call-template name="convertID">
                    <xsl:with-param name="id" select="concat(scs:pickID, '#', ../@publicID)"/>
                </xsl:call-template>
            </xsl:attribute>
            <!--comment/-->
            <xsl:apply-templates/>
        </xsl:element>
    </xsl:template>

    <!-- Value of ID nodes must be converted to a qml identifier -->
    <xsl:template match="scs:agencyURI|scs:authorURI|scs:pickID|scs:methodID|scs:earthModelID|scs:amplitudeID|scs:originID|scs:stationMagnitudeID|scs:preferredOriginID|scs:preferredMagnitudeID|scs:originReference|scs:filterID|scs:slownessMethodID|scs:pickReference|scs:amplitudeReference|scs:referenceSystemID|scs:triggeringOriginID|scs:derivedOriginID|momentMagnitudeID|scs:preferredFocalMechanismID|scs:focalMechanismReference|scs:momentMagnitudeID|scs:greensFunctionID">
        <xsl:element name="{local-name()}">
            <xsl:apply-templates select="@*"/>
            <xsl:call-template name="valueOfIDNode"/>
        </xsl:element>
    </xsl:template>

    <!-- arrival/weight -> arrival/timeWeight-->
    <xsl:template match="scs:arrival/scs:weight">
        <xsl:call-template name="genericNode">
            <xsl:with-param name="name" select="'timeWeight'"/>
        </xsl:call-template>
    </xsl:template>

    <!-- arrival/takeOffAngle -> arrival/takeoffAngle -->
    <xsl:template match="scs:arrival/scs:takeOffAngle">
        <xsl:element name="takeoffAngle">
            <xsl:element name="value">
                <xsl:value-of select="."/>
            </xsl:element>
        </xsl:element>
    </xsl:template>

    <!-- stationMagnitude/magnitude -> stationMagnitude/mag -->
    <xsl:template match="scs:stationMagnitude/scs:magnitude|scs:magnitude/scs:magnitude">
        <xsl:call-template name="genericNode">
            <xsl:with-param name="name" select="'mag'"/>
        </xsl:call-template>
    </xsl:template>

    <!-- amplitude/amplitude -> amplitude/genericAmplitude -->
    <xsl:template match="scs:amplitude/scs:amplitude">
        <xsl:call-template name="genericNode">
            <xsl:with-param name="name" select="'genericAmplitude'"/>
        </xsl:call-template>
    </xsl:template>

    <!-- origin/uncertainty -> origin/originUncertainty -->
    <xsl:template match="scs:origin/scs:uncertainty">
        <xsl:call-template name="genericNode">
            <xsl:with-param name="name" select="'originUncertainty'"/>
        </xsl:call-template>
    </xsl:template>

    <!-- waveformID: SCS uses a child element 'resourceURI', QML
         inserts the URI directly as value -->
    <xsl:template match="scs:waveformID">
        <xsl:element name="{local-name()}">
            <xsl:apply-templates select="@*"/>
            <xsl:if test="scs:resourceURI">
                <xsl:call-template name="convertID">
                    <xsl:with-param name="id" select="scs:resourceURI"/>
                </xsl:call-template>
            </xsl:if>
        </xsl:element>
    </xsl:template>

    <!-- comment: SCS uses a child element 'id', QML an attribute 'id' -->
    <xsl:template match="scs:comment">
        <xsl:element name="{local-name()}">
            <xsl:if test="scs:id">
                <xsl:attribute name="id">
                    <xsl:call-template name="convertID">
                        <xsl:with-param name="id" select="scs:id"/>
                    </xsl:call-template>
                </xsl:attribute>
            </xsl:if>
            <xsl:apply-templates/>
        </xsl:element>
    </xsl:template>

    <!-- Generic transformation of all attributes of an element. If the
         attribute name is 'eventID' it is transfered to a QML id -->
    <xsl:template match="@*">
        <xsl:variable name="attName" select="local-name()"/>
        <xsl:attribute name="{$attName}">
            <xsl:choose>
                <xsl:when test="$attName=$PID">
                    <xsl:call-template name="convertID">
                        <xsl:with-param name="id" select="string(.)"/>
                    </xsl:call-template>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="string(.)"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:attribute>
    </xsl:template>

<!--
    ************************************************************************
    Named Templates
    ************************************************************************
-->

    <!-- Generic and recursively transformation of elements and their
         attributes -->
    <xsl:template name="genericNode">
        <xsl:param name="name"/>
        <xsl:param name="reqPID"/>
        <xsl:variable name="nodeName">
            <xsl:choose>
                <xsl:when test="$name">
                    <xsl:value-of select="$name"/>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="local-name()"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:element name="{$nodeName}">
            <xsl:apply-templates select="@*"/>
            <xsl:if test="$reqPID">
                <xsl:attribute name="{$PID}">
                    <xsl:call-template name="convertOptionalID">
                        <xsl:with-param name="id" select="@publicID"/>
                    </xsl:call-template>
                </xsl:attribute>
            </xsl:if>
            <xsl:apply-templates/>
        </xsl:element>
    </xsl:template>

    <!-- Converts and returns value of an id node -->
    <xsl:template name="valueOfIDNode">
        <xsl:call-template name="convertOptionalID">
            <xsl:with-param name="id" select="string(.)"/>
        </xsl:call-template>
    </xsl:template>

    <!-- Converts a scs id to a quakeml id. If the scs id is not set
         the constant 'NA' is used -->
    <xsl:template name="convertOptionalID">
        <xsl:param name="id"/>
        <xsl:choose>
            <xsl:when test="$id">
                <xsl:call-template name="convertID">
                    <xsl:with-param name="id" select="$id"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
                <xsl:call-template name="convertID">
                    <!--xsl:with-param name="id" select="concat('NA-', generate-id())"/-->
                    <xsl:with-param name="id" select="'NA'"/>
                </xsl:call-template>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <!-- Converts a scs id to a quakeml id -->
    <xsl:template name="convertID">
        <xsl:param name="id"/>
        <xsl:value-of select="concat($ID_PREFIX, translate($id, ' :', '__'))"/>
    </xsl:template>

</xsl:stylesheet>

