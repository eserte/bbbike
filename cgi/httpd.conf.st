<%
    if (!$rooturl) { $rooturl = "/bbbike" }
    if (!$cgiurl)  { $cgiurl = $rooturl."/cgi" }
%>
ScriptAlias <%=$cgiurl%>/bbbike.cgi <%=$rootdir%>/cgi/bbbike.cgi
ScriptAlias <%=$cgiurl%>/bbbike.en.cgi <%=$rootdir%>/cgi/bbbike.cgi
ScriptAlias <%=$cgiurl%>/bbbike2.cgi <%=$rootdir%>/cgi/bbbike.cgi
ScriptAlias <%=$cgiurl%>/browserinfo.cgi <%=$rootdir%>/lib/BrowserInfo.pm
Alias <%=$rooturl%>/html/ <%=$rootdir%>/html/
Alias <%=$rooturl%>/images/ <%=$rootdir%>/images/
