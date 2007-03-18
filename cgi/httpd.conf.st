<%
    if (!$rooturl) { $rooturl = "/bbbike" }
    if (!$cgiurl)  { $cgiurl = $rooturl."/cgi" }
%>
ScriptAlias <%=$cgiurl%>/bbbike.cgi <%=$rootdir%>/cgi/bbbike.cgi
ScriptAlias <%=$cgiurl%>/bbbike.en.cgi <%=$rootdir%>/cgi/bbbike.cgi
ScriptAlias <%=$cgiurl%>/bbbike2.cgi <%=$rootdir%>/cgi/bbbike.cgi
ScriptAlias <%=$cgiurl%>/bbbike2.en.cgi <%=$rootdir%>/cgi/bbbike.cgi
ScriptAlias <%=$cgiurl%>/browserinfo.cgi <%=$rootdir%>/lib/BrowserInfo.pm
<% for my $script (qw(mapserver_address.cgi
		      mapserver_comment.cgi
		      wapbbbike.cgi
		      bbbike-data.cgi
		      bbbikegooglemap.cgi
		      bbbikegooglemap2.cgi
		  )) { %>
ScriptAlias <%=$cgiurl%>/<%=$script%> <%=$rootdir%>/cgi/<%=$script%>
<% } %>
Alias <%=$rooturl%>/html/ <%=$rootdir%>/html/
Alias <%=$rooturl%>/images/ <%=$rootdir%>/images/

ErrorDocument 404 <%=$rooturl%>/html/error404.html
