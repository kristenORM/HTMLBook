<xsl:stylesheet version="1.0"
		xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
		xmlns:exsl="http://exslt.org/common"
		xmlns:h="http://www.w3.org/1999/xhtml"
		xmlns:l="http://docbook.sourceforge.net/xmlns/l10n/1.0"
		xmlns="http://www.w3.org/1999/xhtml"
		extension-element-prefixes="exsl"
		exclude-result-prefixes="exsl h">

  <xsl:output method="xml"
              encoding="UTF-8"/>
  <xsl:preserve-space elements="*"/>

  <!-- Default rule for TOC generation -->

  <!-- All XREFs must be tagged with a @data-type containing XREF -->
  <xsl:template match="h:a[contains(@data-type, 'xref')]" name="process-as-xref">
    <xsl:param name="autogenerate-xrefs" select="$autogenerate-xrefs"/>
    <xsl:param name="xref.elements.pagenum.in.class" select="$xref.elements.pagenum.in.class"/>
    <xsl:param name="autogenerate.xref.pagenum.style" select="$autogenerate.xref.pagenum.style"/>

    <xsl:variable name="calculated-output-href">
      <xsl:call-template name="calculate-output-href">
	<xsl:with-param name="source-href-value" select="@href"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="href-anchor" select="substring-after($calculated-output-href, '#')"/>
    <xsl:variable name="is-xref">
      <xsl:call-template name="href-is-xref">
	<xsl:with-param name="href-value" select="@href"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:copy>
      <xsl:apply-templates select="@*[not(name(.) = 'href')]"/>
      <xsl:attribute name="href">
	<xsl:value-of select="$calculated-output-href"/>
      </xsl:attribute>
        <xsl:choose>
	  <!-- Generate XREF text node if $autogenerate-xrefs is enabled -->
	  <xsl:when test="($autogenerate-xrefs = 1) and ($is-xref = 1)">
	    <xsl:choose>
	      <!-- If we can locate the target, add data-xref-pagenum-style attr if autogenerate.xref.pagenum.style is enabled, reprocess class attribute to add "pagenum" if needed, and process gentext with "xref-to" -->
	      <xsl:when test="count(key('id', $href-anchor)) > 0">
		<xsl:variable name="target" select="key('id', $href-anchor)[1]"/>
		<xsl:if test="$autogenerate.xref.pagenum.style = 1">
		  <xsl:attribute name="data-xref-pagenum-style">
		    <xsl:apply-templates select="$target" mode="xref-pagenum-style">
		      <xsl:with-param name="target-node" select="$target"/>
		      <xsl:with-param name="xref.pagenum.style" select="@data-xref-pagenum-style"/>
		    </xsl:apply-templates>
		  </xsl:attribute>
		</xsl:if>
		<xsl:apply-templates select="." mode="class.attribute">
		  <xsl:with-param name="xref.elements.pagenum.in.class" select="$xref.elements.pagenum.in.class"/>
		  <xsl:with-param name="xref.target" select="$target"/>
		</xsl:apply-templates>
		<xsl:apply-templates select="$target" mode="xref-to">
		  <xsl:with-param name="referrer" select="."/>
		  <xsl:with-param name="xrefstyle">
		    <xsl:call-template name="calculate-xrefstyle">
		      <xsl:with-param name="data-xrefstyle-attr" select="@data-xrefstyle"/>
		    </xsl:call-template>
		  </xsl:with-param>
		</xsl:apply-templates>
	      </xsl:when>
	      <!-- We can't locate the target; fall back on ??? -->
	      <xsl:otherwise>
		<xsl:call-template name="log-message">
		  <xsl:with-param name="type" select="'WARNING'"/>
		  <xsl:with-param name="message">
		    <xsl:text>Unable to locate target for XREF with @href value: </xsl:text>
		    <xsl:value-of select="@href"/>
		  </xsl:with-param>
		</xsl:call-template>
		<xsl:text>???</xsl:text>
	      </xsl:otherwise>
	    </xsl:choose>
	  </xsl:when>
	  <!-- Otherwise, just process node as is -->
	  <xsl:otherwise>
	    <xsl:apply-templates/>
	  </xsl:otherwise>
	</xsl:choose>
    </xsl:copy>
  </xsl:template>

  <!-- href and content handling for a elements that are not indexterms, xrefs, or footnoterefs -->
  <xsl:template match="h:a[not((contains(@data-type, 'xref')) or
		               (contains(@data-type, 'footnoteref')) or
			       (contains(@data-type, 'indexterm')))][@href]">
    <xsl:param name="url.in.parens" select="$url.in.parens"/>
    <!-- If the element is empty, does not have data-type="link", and  is a valid XREF, go ahead and treat it like an <a> element with data-type="xref" -->
    <xsl:variable name="is-xref">
      <xsl:call-template name="href-is-xref">
	<xsl:with-param name="href-value" select="@href"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="(not(node())) and 
		      ($is-xref = 1) and
		      not(@data-type='link')">
	<xsl:call-template name="process-as-xref"/>
      </xsl:when>
      <!-- Otherwise just process href and apply-templates for everything else -->
      <xsl:otherwise>
	<xsl:copy>
	  <xsl:apply-templates select="@*[not(name(.) = 'href')]"/>
	  <xsl:attribute name="href">
	    <xsl:call-template name="calculate-output-href">
	      <xsl:with-param name="source-href-value" select="@href"/>
	    </xsl:call-template>
	  </xsl:attribute>
	  <xsl:apply-templates/>
	</xsl:copy>
	<xsl:if test="$url.in.parens = 1">
      	  <!-- Put the URL after the <a> element in parentheses, unless one of the following two cases is true:
	       1. A @class attribute containing the text orm:hideurl was specified
	       2. The href is a mailto link.
	       3. The <a> has data-type="link"
	       4. Text node is identical to @url attribute (or matches if http:// or http://www. is dropped) -->
	  <xsl:variable name="trimmed_href_attr">
	    <xsl:call-template name="trim-url">
	      <xsl:with-param name="url-to-trim" select="@href"/>
	    </xsl:call-template>
	  </xsl:variable>
	  <xsl:variable name="trimmed_anchor_text_node">
	    <xsl:call-template name="trim-url">
	      <xsl:with-param name="url-to-trim" select="."/>
	    </xsl:call-template>
	  </xsl:variable>
	  <xsl:variable name="href-is-an-xref-not-a-hyperlink">
	    <xsl:call-template name="href-is-xref"/>
	  </xsl:variable>
	  <xsl:variable name="render_url_in_parens">
	    <xsl:choose>
	      <xsl:when test="contains(@class, 'orm:hideurl')">0</xsl:when>
	      <xsl:when test="contains(@href, 'mailto:')">0</xsl:when>
	      <xsl:when test="@data-type = 'link'">0</xsl:when>
	      <xsl:when test=". = @href">0</xsl:when>
	      <xsl:when test="$trimmed_href_attr = $trimmed_anchor_text_node">0</xsl:when>
	      <xsl:when test="$href-is-an-xref-not-a-hyperlink = 1">0</xsl:when>
	      <xsl:otherwise>1</xsl:otherwise>
	    </xsl:choose>
	  </xsl:variable>
	  <xsl:if test="$render_url_in_parens = 1">
	    <span class="print_url_in_parens"> (<span class="print_url"><xsl:value-of select="@href"/></span>)</span>
	  </xsl:if>
	</xsl:if>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Handling for generating values for data-xref-pagenum attribute -->
  <!-- Override with element-specific templates as needed -->
  <!-- target-node = target element referenced by XREF -->
  <xsl:template match="*" mode="xref-pagenum-style">
    <xsl:param name="target-node" select="."/>
    <xsl:param name="xref.pagenum.style"/>
    <xsl:variable name="pagenum-style">
      <xsl:choose>
	<!-- If an xref-pagenum-style is explicitly passed in, use that -->
	<xsl:when test="$xref.pagenum.style != ''">
	  <xsl:value-of select="$xref.pagenum.style"/>
	</xsl:when>
	<xsl:otherwise>
	  <!-- Otherwise try using xref.pagenum.style.for.section.by.data-type param for determining section pagenum style -->
	  <xsl:call-template name="get-param-value-from-key">
	    <xsl:with-param name="parameter" select="$xref.pagenum.style.for.section.by.data-type"/>
	    <xsl:with-param name="key" select="$target-node/@data-type"/>
	  </xsl:call-template>
	</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    
    <xsl:choose>
      <!-- 1. If we found a pagenum.style, use that -->
      <xsl:when test="normalize-space($pagenum-style) != ''">
	<xsl:value-of select="normalize-space($pagenum-style)"/>
      </xsl:when>
      <!-- 2. If we didn't find a pagenum style, and target-node has a parent, call on parent node -->
      <xsl:when test="$target-node[parent::*]">
	<xsl:apply-templates select="$target-node/.." mode="xref-pagenum-style"/>
      </xsl:when>
      <!-- 3. Otherwise, if we didn't find a pagenum style, and no parent, use the default style (decimal) -->
      <xsl:otherwise>decimal</xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- Adapted from docbook-xsl templates in xhtml/xref.xsl -->
  <xsl:template match="*" mode="xref-to">
    <xsl:param name="referrer"/>
    <xsl:param name="xrefstyle"/>
    <xsl:param name="verbose" select="1"/>
    
    <xsl:apply-templates select="." mode="object.xref.markup">
      <xsl:with-param name="purpose" select="'xref'"/>
      <xsl:with-param name="xrefstyle" select="$xrefstyle"/>
      <xsl:with-param name="referrer" select="$referrer"/>
      <xsl:with-param name="verbose" select="$verbose"/>
    </xsl:apply-templates>
  </xsl:template>

  <!-- Special xref-to handling for refentries -->
  <xsl:template match="h:div[contains(@class,'refentry')]" mode="xref-to">
    <xsl:choose>
      <xsl:when test="descendant::*[@class='refname']">
	<!-- Choose the first descendant element with class of refname, if one exists, and wrap in "code" tag -->
	<code class="refentry">
	  <xsl:value-of select="descendant::*[@class='refname'][1]"/>
	</code>
      </xsl:when>
      <xsl:otherwise>
	<!-- Otherwise, throw warning, and print out ??? -->
	<xsl:call-template name="log-message">
	  <xsl:with-param name="type" select="'WARNING'"/>
	  <xsl:with-param name="message">
	    <xsl:text>Cannot output gentext for XREF to refentry (id:</xsl:text>
	    <xsl:value-of select="@id"/>
	    <xsl:text>) that does not contain an element with class of refname</xsl:text>
	  </xsl:with-param>
	</xsl:call-template>
	<xsl:text>???</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

    <!-- Special xref-to handling for refsect1/refsect2 -->
  <xsl:template match="h:div[@class='refsect1'] | h:div[@class='refsect2']" mode="xref-to">
    <xsl:choose>
      <xsl:when test="h:h6[1]">
  <!-- Choose the first descendant, h6 element, if one exists, drop in text-->
    <xsl:text>“</xsl:text><xsl:value-of select="h:h6[1]"/><xsl:text>”</xsl:text>
      </xsl:when>
      <xsl:otherwise>
  <!-- Otherwise, throw warning, and print out ??? -->
  <xsl:call-template name="log-message">
    <xsl:with-param name="type" select="'WARNING'"/>
    <xsl:with-param name="message">
      <xsl:text>Cannot output gentext for XREF to refsection (id:</xsl:text>
      <xsl:value-of select="@id"/>
      <xsl:text>) that does not contain a descendant h6 element</xsl:text>
    </xsl:with-param>
  </xsl:call-template>
  <xsl:text>???</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

<!-- Special xref-to handling for admonitions (notes, tips, and warnings) -->
  <xsl:template match="h:div[contains(@data-type, 'note') or contains(@data-type, 'tip') or contains(@data-type, 'warning')]" mode="xref-to">
    <xsl:choose>
      <xsl:when test="h:h1[1]">
  <!-- Choose the first descendant, h1 element, if one exists, drop in text-->
    <xsl:text>“</xsl:text><xsl:value-of select="h:h1[1]"/><xsl:text>”</xsl:text>
      </xsl:when>
      <xsl:otherwise>
  <!-- Otherwise, throw warning, and print out ??? -->
  <xsl:call-template name="log-message">
    <xsl:with-param name="type" select="'WARNING'"/>
    <xsl:with-param name="message">
      <xsl:text>Cannot output gentext for XREF to Admonition (id:</xsl:text>
      <xsl:value-of select="@id"/>
      <xsl:text>) that does not contain a descendant h1 element</xsl:text>
    </xsl:with-param>
  </xsl:call-template>
  <xsl:text>???</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!-- ADDING HANDLING FOR XREFS TO EQUATION -->
  <!-- Adapted from docbook-xsl templates in xhtml/xref.xsl -->
  <xsl:template match="h:div[@data-type='equation']" mode="xref-to">
    <xsl:param name="referrer"/>
    <xsl:param name="xrefstyle"/>
    <xsl:param name="verbose" select="1"/>
    
    <xsl:choose>
      <xsl:when test="h:h5">
        <xsl:apply-templates select="." mode="object.xref.markup">
          <xsl:with-param name="purpose" select="'xref'"/>
          <!-- BEGIN OVERRIDE -->
          <xsl:with-param name="xrefstyle" select="'template:Equation %n'"/>
          <!-- END OVERRIDE -->
          <xsl:with-param name="referrer" select="$referrer"/>
          <xsl:with-param name="verbose" select="$verbose"/>
        </xsl:apply-templates>
      </xsl:when>
      <xsl:otherwise>
        <!-- Otherwise, throw warning, and print out ??? -->
        <xsl:call-template name="log-message">
          <xsl:with-param name="type" select="'WARNING'"/>
          <xsl:with-param name="message">
            <xsl:text>Cannot output gentext for XREF to refsection (id:</xsl:text>
            <xsl:value-of select="@id"/>
            <xsl:text>) that does not contain a descendant h6 element</xsl:text>
          </xsl:with-param>
        </xsl:call-template>
        <xsl:text>???</xsl:text>
      </xsl:otherwise>

    </xsl:choose>

  </xsl:template>
  

  <!-- Adapted from docbook-xsl templates in common/gentext.xsl -->
  <!-- For simplicity, not folding in all the special 'select: ' logic (some of which is FO-specific, anyway) -->
<xsl:template match="*" mode="object.xref.markup">
  <xsl:param name="purpose" select="'xref'"/>
  <xsl:param name="xrefstyle"/>
  <xsl:param name="referrer"/>
  <xsl:param name="verbose" select="1"/>

  <xsl:variable name="template">
    <xsl:choose>
      <xsl:when test="starts-with(normalize-space($xrefstyle), 'template:')">
        <xsl:value-of select="substring-after(normalize-space($xrefstyle), 'template:')"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="." mode="object.xref.template">
          <xsl:with-param name="purpose" select="$purpose"/>
          <xsl:with-param name="xrefstyle" select="$xrefstyle"/>
          <xsl:with-param name="referrer" select="$referrer"/>
        </xsl:apply-templates>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:if test="$template = '' and $verbose != 0">
    <xsl:call-template name="log-message">
      <xsl:with-param name="type" select="'DEBUG'"/>
      <xsl:with-param name="message">
	<xsl:text>object.xref.markup: empty xref template</xsl:text>
	<xsl:text> for linkend="</xsl:text>
	<xsl:value-of select="@id|@xml:id"/>
	<xsl:text>" and @xrefstyle="</xsl:text>
	<xsl:value-of select="$xrefstyle"/>
	<xsl:text>"</xsl:text>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:if>

  <xsl:choose>
    <xsl:when test="normalize-space($template) != ''">
      <xsl:call-template name="substitute-markup">
	<xsl:with-param name="purpose" select="$purpose"/>
	<xsl:with-param name="xrefstyle" select="$xrefstyle"/>
	<xsl:with-param name="referrer" select="$referrer"/>
	<xsl:with-param name="template" select="$template"/>
	<xsl:with-param name="verbose" select="$verbose"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise>
      <xsl:text>???</xsl:text>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- ============================================================ -->

<xsl:template match="*" mode="object.xref.template">
  <xsl:param name="purpose"/>
  <xsl:param name="xrefstyle"/>
  <xsl:param name="referrer"/>

  <xsl:variable name="number-and-title-template">
    <xsl:call-template name="gentext.template.exists">
      <xsl:with-param name="context" select="'xref-number-and-title'"/>
      <xsl:with-param name="name">
        <xsl:call-template name="semantic-name"/>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:variable>

  <xsl:variable name="number-template">
    <xsl:call-template name="gentext.template.exists">
      <xsl:with-param name="context" select="'xref-number'"/>
      <xsl:with-param name="name">
        <xsl:call-template name="semantic-name"/>
      </xsl:with-param>
    </xsl:call-template>
  </xsl:variable>

  <xsl:variable name="context">
    <xsl:choose>
      <!-- First, allow $xrefstyle to override standard xref-type handling -->
      <xsl:when test="($xrefstyle = 'xref-number-and-title' and $number-and-title-template != 0) or
		      ($xrefstyle = 'xref-number' and $number-template != 0) or
		      ($xrefstyle = 'xref')">
	<xsl:value-of select="$xrefstyle"/>
      </xsl:when>
      <!-- Otherwise, if we're XREFing a section or a part div, use the $xref.type.for.section.by.data-type variable -->
      <xsl:when test="self::h:section or self::h:div[contains(@data-type, 'part')]">
	<xsl:variable name="xref-type">
	  <xsl:call-template name="get-param-value-from-key">
	    <xsl:with-param name="parameter" select="$xref.type.for.section.by.data-type"/>
	    <xsl:with-param name="key" select="@data-type"/>
	  </xsl:call-template>
	</xsl:variable>
	<xsl:choose>
	  <xsl:when test="($xref-type = 'xref-number-and-title' and $number-and-title-template != 0) or ($xref-type = 'xref-number' and $number-template != 0)">
	    <xsl:value-of select="$xref-type"/>
	  </xsl:when>
	  <xsl:otherwise>
	    <xsl:text>xref</xsl:text>
	  </xsl:otherwise>
	</xsl:choose>
      </xsl:when>
      <xsl:otherwise>
	<xsl:apply-templates select="." mode="xref-type">
	  <xsl:with-param name="number-and-title-template" select="$number-and-title-template"/>
	  <xsl:with-param name="number-template" select="$number-template"/>
	</xsl:apply-templates>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:call-template name="gentext.template">
    <xsl:with-param name="context" select="$context"/>
    <xsl:with-param name="name">
      <xsl:call-template name="semantic-name"/>
    </xsl:with-param>
    <xsl:with-param name="purpose" select="$purpose"/>
    <xsl:with-param name="xrefstyle" select="$xrefstyle"/>
    <xsl:with-param name="referrer" select="$referrer"/>
  </xsl:call-template>

</xsl:template>

<!-- ============================================================ -->

<!-- xref-type templates: should return a value of 'xref-number-and-title', 'xref-number', or 'xref' -->
<!-- If returning 'xref-number-and-title' or 'xref-number', may want to first check if corresponding template exists -->

<xsl:template match="h:table|h:figure|h:div[contains(@data-type, 'example')]" mode="xref-type">
  <xsl:param name="number-and-title-template" select="0"/>
  <xsl:param name="number-template" select="0"/>
  <xsl:choose>
    <xsl:when test="$number-template != 0">
      <xsl:text>xref-number</xsl:text>
    </xsl:when>
    <xsl:otherwise>
      <xsl:text>xref</xsl:text>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- Default xref-type template -->
<xsl:template match="*" mode="xref-type">
  <xsl:param name="number-and-title-template"/>
  <xsl:param name="number-template"/>
  <xsl:text>xref</xsl:text>
</xsl:template>

<!-- ============================================================ -->

<!-- Adapted from docbook-xsl templates in common/gentext.xsl -->
<!-- For reasons of simplicity and relevance, only supporting %n, %t, and %d substitutions -->
<xsl:template name="substitute-markup">
  <xsl:param name="template" select="''"/>
  <xsl:param name="allow-anchors" select="'0'"/>
  <xsl:param name="title" select="''"/>
  <xsl:param name="subtitle" select="''"/>
  <xsl:param name="docname" select="''"/>
  <xsl:param name="label" select="''"/>
  <xsl:param name="pagenumber" select="''"/>
  <xsl:param name="purpose"/>
  <xsl:param name="xrefstyle"/>
  <xsl:param name="referrer"/>
  <xsl:param name="verbose"/>

  <xsl:choose>
    <xsl:when test="contains($template, '%')">
      <xsl:value-of select="substring-before($template, '%')"/>
      <xsl:variable name="candidate"
             select="substring(substring-after($template, '%'), 1, 1)"/>
      <xsl:choose>
        <xsl:when test="$candidate = 't'">
          <xsl:apply-templates select="." mode="insert.title.markup">
            <xsl:with-param name="purpose" select="$purpose"/>
            <xsl:with-param name="xrefstyle" select="$xrefstyle"/>
            <xsl:with-param name="title">
              <xsl:choose>
                <xsl:when test="$title != ''">
                  <xsl:copy-of select="$title"/>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:apply-templates select="." mode="title.markup">
                    <xsl:with-param name="allow-anchors" select="$allow-anchors"/>
                    <xsl:with-param name="verbose" select="$verbose"/>
                  </xsl:apply-templates>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:with-param>
          </xsl:apply-templates>
        </xsl:when>
        <xsl:when test="$candidate = 'n'">
          <xsl:apply-templates select="." mode="insert.label.markup">
            <xsl:with-param name="purpose" select="$purpose"/>
            <xsl:with-param name="xrefstyle" select="$xrefstyle"/>
            <xsl:with-param name="label">
              <xsl:choose>
                <xsl:when test="$label != ''">
                  <xsl:copy-of select="$label"/>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:apply-templates select="." mode="label.markup"/>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:with-param>
          </xsl:apply-templates>
        </xsl:when>
        <xsl:when test="$candidate = 'd'">
          <xsl:apply-templates select="." mode="insert.direction.markup">
            <xsl:with-param name="purpose" select="$purpose"/>
            <xsl:with-param name="xrefstyle" select="$xrefstyle"/>
            <xsl:with-param name="direction">
              <xsl:choose>
                <xsl:when test="$referrer">
                  <xsl:variable name="referent-is-below">
                    <xsl:for-each select="preceding::h:a[@data-type='xref']">
                      <xsl:if test="generate-id(.) = generate-id($referrer)">1</xsl:if>
                    </xsl:for-each>
                  </xsl:variable>
                  <xsl:choose>
                    <xsl:when test="$referent-is-below = ''">
		      <xsl:call-template name="get-localization-value">
			<xsl:with-param name="gentext-key" select="'above'"/>
		      </xsl:call-template>
		    </xsl:when>
                    <xsl:otherwise>
		      <xsl:call-template name="get-localization-value">
			<xsl:with-param name="gentext-key" select="'below'"/>
		      </xsl:call-template>
                    </xsl:otherwise>
                  </xsl:choose>
                </xsl:when>
                <xsl:otherwise>
		  <xsl:call-template name="log-message">
		    <xsl:with-param name="type" select="'WARNING'"/>
		    <xsl:with-param name="message">
                      <xsl:text>Attempt to use %d in gentext with no referrer!</xsl:text>
		    </xsl:with-param>
		  </xsl:call-template>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:with-param>
          </xsl:apply-templates>
        </xsl:when>
        <xsl:when test="$candidate = '%' ">
          <xsl:text>%</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text>%</xsl:text><xsl:value-of select="$candidate"/>
        </xsl:otherwise>
      </xsl:choose>
      <!-- recurse with the rest of the template string -->
      <xsl:variable name="rest"
            select="substring($template,
            string-length(substring-before($template, '%'))+3)"/>
      <xsl:call-template name="substitute-markup">
        <xsl:with-param name="template" select="$rest"/>
        <xsl:with-param name="allow-anchors" select="$allow-anchors"/>
        <xsl:with-param name="title" select="$title"/>
        <xsl:with-param name="subtitle" select="$subtitle"/>
        <xsl:with-param name="docname" select="$docname"/>
        <xsl:with-param name="label" select="$label"/>
        <xsl:with-param name="pagenumber" select="$pagenumber"/>
        <xsl:with-param name="purpose" select="$purpose"/>
        <xsl:with-param name="xrefstyle" select="$xrefstyle"/>
        <xsl:with-param name="referrer" select="$referrer"/>
        <xsl:with-param name="verbose" select="$verbose"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="$template"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- ============================================================ -->

<!-- insert.title.markup, insert.label.markup, and insert.direction.markup templates; adapted from docbook-xsl xhtml/xref.xsl stylesheet -->

<xsl:template match="*" mode="insert.label.markup">
  <xsl:param name="purpose"/>
  <xsl:param name="xrefstyle"/>
  <xsl:param name="label"/>

  <xsl:copy-of select="$label"/>
</xsl:template>

<xsl:template match="*" mode="insert.direction.markup">
  <xsl:param name="purpose"/>
  <xsl:param name="xrefstyle"/>
  <xsl:param name="direction"/>

  <xsl:copy-of select="$direction"/>
</xsl:template>

<xsl:template match="*" mode="insert.title.markup">
  <xsl:param name="purpose"/>
  <xsl:param name="xrefstyle"/>
  <xsl:param name="title"/>

  <xsl:copy-of select="$title"/>

</xsl:template>

<!-- ============================================================ -->

<!-- Adapted from docbook-xsl common/l10.xsl stylesheet -->
<xsl:template name="gentext.template.exists">
  <xsl:param name="context" select="'default'"/>
  <xsl:param name="name" select="'default'"/>
  <xsl:param name="purpose"/>
  <xsl:param name="xrefstyle"/>
  <xsl:param name="referrer"/>
  <xsl:param name="lang" select="$book-language"/>

  <xsl:variable name="template">
    <xsl:call-template name="gentext.template">
      <xsl:with-param name="context" select="$context"/>
      <xsl:with-param name="name" select="$name"/>
      <xsl:with-param name="purpose" select="$purpose"/>
      <xsl:with-param name="xrefstyle" select="$xrefstyle"/>
      <xsl:with-param name="referrer" select="$referrer"/>
      <xsl:with-param name="lang" select="$lang"/>
      <xsl:with-param name="verbose" select="0"/>
    </xsl:call-template>
  </xsl:variable>
  
  <xsl:choose>
    <xsl:when test="string-length($template) != 0">1</xsl:when>
    <xsl:otherwise>0</xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- ============================================================ -->

<!-- Adapted from docbook-xsl common/l10.xsl stylesheet -->
<!-- ENORMOUSLY simplifying the logic here -->
<xsl:template name="gentext.template">
  <xsl:param name="context" select="'default'"/>
  <xsl:param name="name" select="'default'"/>
  <xsl:param name="purpose"/>
  <xsl:param name="xrefstyle"/>
  <xsl:param name="referrer"/>
  <xsl:param name="lang" select="$book-language"/>
  <xsl:param name="verbose" select="1"/>

  <xsl:variable name="localizations-nodes" select="exsl:node-set($localizations)"/>

  <xsl:variable name="context.node"
		select="$localizations-nodes//l:l10n/l:context[@name=$context][1]"/>

  <xsl:if test="count($context.node) = 0
		and $verbose != 0">
    <xsl:call-template name="log-message">
      <xsl:with-param name="type" select="'DEBUG'"/>
      <xsl:with-param name="message">
	<xsl:text>No context named "</xsl:text>
	<xsl:value-of select="$context"/>
	<xsl:text>" exists in the "</xsl:text>
	<xsl:value-of select="$lang"/>
	<xsl:text>" localization.</xsl:text>    
      </xsl:with-param>
    </xsl:call-template>
  </xsl:if>

  <xsl:choose>
    <!-- If there's an $xrefstyle specified, first check for matching template @name and @style -->
    <xsl:when test="$xrefstyle != '' and $context.node/l:template[@name=$name and @style=$xrefstyle and @text]">
      <xsl:value-of select="$context.node/l:template[@name=$name and @style=$xrefstyle and @text][1]/@text"/>
    </xsl:when>
    <!-- If no $xrefstyle, just chekc for matching template @name -->
    <xsl:when test="$context.node/l:template[@name=$name and @text]">
      <xsl:value-of select="$context.node/l:template[@name=$name and @text][1]/@text"/>
    </xsl:when>
    <xsl:when test="$verbose = 0">
      <!-- silence -->
    </xsl:when>
    <xsl:otherwise>
      <xsl:call-template name="log-message">
	<xsl:with-param name="type" select="'DEBUG'"/>
	<xsl:with-param name="message">
	  <xsl:text>No template for "</xsl:text>
	  <xsl:value-of select="$name"/>
	  <xsl:text>" (or any of its leaves) exists in the context named "</xsl:text>
	  <xsl:value-of select="$context"/>
	  <xsl:text>" in the "</xsl:text>
	  <xsl:value-of select="$lang"/>
	  <xsl:text>" localization.</xsl:text>
	</xsl:with-param>
      </xsl:call-template>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- Utility template for determining whether an @href is a valid XREF -->
<!-- Returns 1 if href is an XREF, and 0 if not -->
<xsl:template name="href-is-xref">
  <xsl:param name="href-value" select="@href"/>
  <xsl:choose>
    <xsl:when test="starts-with($href-value, '#')">1</xsl:when>
    <xsl:when test="starts-with($href-value, 'mailto:')">0</xsl:when>
    <!-- If we weren't worried about XSLT 1.0 compatibility, might be better to use a regex here -->
    <xsl:when test="contains($href-value, '://')">0</xsl:when>
    <xsl:otherwise>1</xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- Utility template for processing @href attributes on <a> elements -->
<!-- For XREFs, grab either the text content after the last # sign, or all the content if there is no # sign -->
<!-- For non-XREFs, don't touch at all -->
<xsl:template name="calculate-output-href">
  <xsl:param name="source-href-value" select="@href"/>
  <xsl:param name="href-is-xref"/>

  <xsl:variable name="is-xref">
    <xsl:choose>
      <xsl:when test="($href-is-xref = 0) or ($href-is-xref = 1)">
	<xsl:value-of select="$href-is-xref"/>
      </xsl:when>
      <xsl:otherwise>
	<xsl:call-template name="href-is-xref">
	  <xsl:with-param name="href-value" select="$source-href-value"/>
	</xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:choose>
    <xsl:when test="$is-xref = 1">
      <xsl:choose>
	<!-- If there is more than one # sign in content, recursively call template to get content after first # -->
	<xsl:when test="contains(substring-after($source-href-value, '#'), '#')">
	  <xsl:call-template name="calculate-output-href">
	    <xsl:with-param name="source-href-value" select="substring-after($source-href-value, '#')"/>
	    <xsl:with-param name="href-is-xref" select="1"/>
	  </xsl:call-template>
	</xsl:when>
	<!-- If there is a # sign in content, grab the # and all content thereafter -->
	<xsl:when test="contains($source-href-value, '#')">
	  <xsl:value-of select="concat('#', substring-after($source-href-value, '#'))"/>
	</xsl:when>
	<!-- Otherwise, just use all the text as is, with a # sign prepended-->
	<xsl:otherwise>
	  <xsl:value-of select="concat('#', $source-href-value)"/>
	</xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:otherwise>
      <!-- Just use the text as is -->
      <xsl:value-of select="$source-href-value"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

  <!-- Template to calculate xrefstyle from data-xrefstyle attribute -->
  <xsl:template name="calculate-xrefstyle">
    <xsl:param name="data-xrefstyle-attr"/>
    <!-- Currently support the following enumerated custom xrefstyles -->
    <xsl:choose>
      <!-- select: labelnumber -->
      <xsl:when test="starts-with($data-xrefstyle-attr, 'select:') and 
		      contains(substring-after($data-xrefstyle-attr, 'select:'), 'labelnumber')">template:%n</xsl:when>
      <!-- chap-num-title -->
      <xsl:when test="$data-xrefstyle-attr = 'chap-num-title'">xref-number-and-title</xsl:when>
      <!-- app-num-title -->
      <xsl:when test="$data-xrefstyle-attr = 'app-num-title'">xref-number-and-title</xsl:when>
      <!-- part-num-title -->
      <xsl:when test="$data-xrefstyle-attr = 'part-num-title'">xref-number-and-title</xsl:when>
    </xsl:choose>
  </xsl:template>

  <!-- Template to trim http:// and http://www from URLs -->
  <xsl:template name="trim-url">
    <xsl:param name="url-to-trim"/>

    <!-- First, trim http://www., http://, or www. prefixes -->
    <xsl:variable name="prefix-trimmed">
      <xsl:choose>
	<xsl:when test="contains($url-to-trim, 'http://www.') and substring-before($url-to-trim, 'http://www.') = ''">
	  <xsl:value-of select="substring-after($url-to-trim, 'http://www.')"/>
	</xsl:when>
	<xsl:when test="contains($url-to-trim, 'http://') and substring-before($url-to-trim, 'http://') = ''">
	  <xsl:value-of select="substring-after($url-to-trim, 'http://')"/>
	</xsl:when>
	<xsl:when test="contains($url-to-trim, 'www.') and substring-before($url-to-trim, 'www.') = ''">
	  <xsl:value-of select="substring-after($url-to-trim, 'www.')"/>
	</xsl:when>
	<xsl:otherwise>
	  <xsl:value-of select="$url-to-trim"/>
	</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <!-- Then trim trailing forward slashes -->
    <xsl:variable name="suffix-trimmed">
      <xsl:choose>
	<xsl:when test="substring($prefix-trimmed, string-length($prefix-trimmed), 1) = '/'">
	  <xsl:value-of select="substring($prefix-trimmed, 1, string-length($prefix-trimmed) - 1)"/>
	</xsl:when>
	<xsl:otherwise>
	  <xsl:value-of select="$prefix-trimmed"/>
	</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    
    <xsl:value-of select="$suffix-trimmed"/>
  </xsl:template>

</xsl:stylesheet> 
