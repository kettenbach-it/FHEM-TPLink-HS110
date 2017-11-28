# Loxone TP-LINK HS100 / HS110

control.cgi can be used in Loxone for connection the HS100/110 outlets.


<h1 id="TP-LINKHS100/HS110steuern-EinrichtungHS100/HS110">Einrichtung HS100/HS110</h1><ul><li>In der TP-Link Kasa App die Steckdose einrichten. Ein Cloud-Zugang muss <em>nicht</em> eingerichtet werden.</li><li>Am Router die IP-Adresse herausfinden. <ul><li>Anm. Bei mir hat sich die erste Steckdose mit dem Hostnamen HS100 registriert. Was passiert, wenn zwei oder mehrere angebunden werden, weiß ich nicht.</li></ul></li></ul><p> </p><h1 id="TP-LINKHS100/HS110steuern-EinrichtungLoxBerry">Einrichtung LoxBerry</h1><ul><li>Diese Datei herunterladen: <a href="/download/attachments/24838213/control.zip?version=1&amp;modificationDate=1511810226000&amp;api=v2" data-linked-resource-id="24838212" data-linked-resource-version="1" data-linked-resource-type="attachment" data-linked-resource-default-alias="control.zip" data-nice-type="Zip Archive" data-linked-resource-content-type="application/zip" data-linked-resource-container-id="24838213" data-linked-resource-container-version="1">control.zip</a></li><li>In folgenden Ordner kopieren<ul><li>Von Windows aus: <code>\\loxberry\loxberry\webfrontend\cgi\plugins\tplink\</code> , </li><li>oder per SSH: <code>/opt/loxberry/webfrontend/cgi/plugins/tplink/</code></li></ul></li><li>Wenn das nicht automatisch der Fall ist, dann chmod +x control.cgi</li></ul><h1 id="TP-LINKHS100/HS110steuern-EinrichtunginLoxone">Einrichtung in Loxone</h1><ul><li>Virtuellen Ausgang erstellen<ul><li>http://&lt;user&gt;:&lt;pass&gt;@loxberry</li></ul></li><li>Virtuellen Ausgangsbefehl erstellen:<ul><li>/admin/plugins/tplink/control.cgi?ip=&lt;IP&gt;&amp;command=on</li><li>/admin/plugins/tplink/control.cgi?ip=&lt;IP&gt;&amp;command=off</li></ul></li></ul><h2 id="TP-LINKHS100/HS110steuern-WelcheKommandogibtes?">Welche Kommando gibt es?</h2><p>Siehe unten.</p><div class="table-wrap"><table class="confluenceTable"><colgroup><col/><col/></colgroup><tbody><tr><th class="confluenceTh">URL-Parameter</th><th class="confluenceTh">Bedeutung</th></tr><tr><td class="confluenceTd">ip=</td><td class="confluenceTd">IP des HS100/110</td></tr><tr><td class="confluenceTd">command=</td><td class="confluenceTd">Kommando</td></tr><tr><td class="confluenceTd">verbose</td><td class="confluenceTd">Wenn gesetzt, wird mehr ausgegeben</td></tr></tbody></table></div><p> </p><h1 id="TP-LINKHS100/HS110steuern-

Woherkommt&#39;s?">Woher kommt's?</h1>

Source:
http://www.loxwiki.eu/pages/viewpage.action?pageId=24838213

Author: Christian Fenzl 2017 for LoxBerry
