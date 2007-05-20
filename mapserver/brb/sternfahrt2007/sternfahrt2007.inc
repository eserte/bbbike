[%
   SET
       YEAR = 2007
       TITLE = "Sternfahrt " _ YEAR _ " - BBBike - Mapserver"
       HEADLINE_HTML = '<img src="' _ BBBIKE_IMAGES_RELURL _ '/stern' _ YEAR _ '_titel.jpg" alt="Sternfahrt ' _ YEAR _ '">'
       MOREINFO_HTML = 'Mehr Informationen zur Sternfahrt ' _ YEAR _ ' am 3. Juni ' _ YEAR _ ' gibt es <a href="http://www.fahrradsternfahrt.de/">hier</a>.<br /><br /><a href="' _ BBBIKE_CGI_RELURL _ '/sternfahrt' _ YEAR _ '-treffpunkte.cgi">Liste aller Treffpunkte</a><br /><br />'
       EXTRA_LAYERS = [{name => "sternfahrt", label => "Routen der Sternfahrt"}, {name => "treffpunkte", label => "Treffpunkte der Sternfahrt"}]
-%]

