# -*- perl -*-

#
# $Id: Brandenburg_DE.pm,v 1.4 2005/04/29 23:37:15 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
#

# Das Land Brandenburg

package Geography::Brandenburg_DE;
use strict;
use vars qw(%parts %kfz);

my $partdef =
    ['Barnim',
     ['Ahrensfelde',
      'Basdorf',
      'Bernau' => ['Birkholzaue', 'Waldsiedlung'],
      'Biesenthal',
      'Blumberg',
      'Klosterfelde',
      'Lanke',
      'Lindenberg',
      'Lobetal',
      'Mehrow-Trappenfelde',
      'Schönerlinde',
      'Schönwalde',
      'Schwanebeck' => ['Neu-Schwanebeck'],
      'Seefeld',
      'Tiefensee',
      'Wandlitz',
      'Werneuchen' => ['Stienitzaue'],
      'Zepernick',
     ],

     'Havelland',
     ['Bredow' => ['Glien'],
      'Brieselang',
      'Dallgow-Döberitz' => ['Rohrbeck'],
      'Falkensee' => ['Falkenhain', 'Finkenkrug', 'Seegefeld'],
      'Ketzin',
      'Perwenitz',
      'Priort',
      'Schönwalde' => ['Siedlung'],
      'Wustermark' => ['Dyrotz', 'Nord'],
     ],

     'Landkreis Dahme-Spree',
     ['Bestensee',
      'Dannenreich' => ['Friedrichshof'],
      'Friedersdorf',
      'Gräbendorf',
      'Kablow',
      'Kiekebusch' => ['Karlshof'],
      'Königs Wusterhausen',
      'Mittenwalde',
      'Motzen',
      'Niederlehme',
      'Pätz',
      'Prieros',
      'Schönefeld',
      'Streganz' => ['Klein Eichholz'],
      'Waltersdorf',
      'Wernsdorf',
      'Wildau',
      'Wolzig',
      'Zernsdorf',
      'Zeuthen',
     ],

     'Landkreis Oder-Spree',
     ['Alt-Stahnsdorf' => 'Neu Stahnsdorf',
      'Erkner',
      'Gosen',
      'Hangelsberg',
      'Hartmannsdorf',
      'Kagel',
      'Markgrafpieske',
      'Schöneiche',
      'Spreeau',
      'Spreenhagen',
      'Woltersdorf',
     ],

     'Märkisch Oderland',
     ['Altlandsberg',
      'Dahlwitz-Hoppegarten',
      'Fredersdorf-Vogelsdorf' => ['Fredersdorf', 'Vogelsdorf'],
      'Herzfelde',
      'Hönow',
      'Münchehofe',
      'Neuenhagen',
      'Rehfelde',
      'Rüdersdorf',
      'Strausberg',
     ],

     'Oberhavelland',
     ['Bärenklau',
      'Birkenwerder',
      'Bötzow' => ['West'],
      'Germendorf',
      'Groß-Ziethen',
      'Hennigsdorf' => ['Nieder Neuendorf', 'Nord', 'Stolpe-Süd'],
      'Hohen Neuendorf' => ['Bergfelde', 'Stolpe', 'Borgsdorf'],
      'Kremmen',
      'Leegebruch',
      'Lehnitz',
      'Mühlenbeck' => ['Feldheim'],
      'Oberkrämer' => ['Klein-Ziethen', 'Vehlefanz'],
      'Oranienburg' => ['Sachsenhausen', 'Eden'],
      'Schildow',
      'Schmachtenhagen',
      'Schönfließ',
      'Schwante',
      'Velten' => ['Hohenschöpping'],
      'Wensickendorf',
      'Zehlendorf',
      'Zühlsdorf',
     ],

     'Potsdam',
     ['Am Schlaatz',
      'Am Stern',
      'Babelsberg',
      'Berliner Vorstadt',
      'Bornim',
      'Bornstedt',
      'Brandenburger Vorstadt',
      'Drewitz',
      'Eiche',
      'Innenstadt',
      'Jäger Vorstadt',
      'Kirchsteigfeld',
      'Nauener Vorstadt',
      'Nedlitz',
      'Potsdam West',
      'Sacrow',
      'Teltower Vorstadt',
      'Templiner Vorstadt',
      'Waldstadt',
      'Wildpark',
      'Zentrum Ost',
     ],

     'Potsdam-Mittelmark',
     ['Beelitz-Heilstätten',
      'Bergholz-Rehbrücke',
      'Bochow',
      'Damsdorf',
      'Derwitz',
      'Fahrland-Krampnitz',
      'Ferch',
      'Ferch-Schmerberg',
      'Fichtenwalde',
      'Geltow',
      'Golm',
      'Groß Kreutz',
      'Kleinmachnow' => ['Dreilinden'],
      'Langerwisch',
      'Lehnin',
      'Michendorf',
      'Philippsthal',
      'Phöben',
      'Saarmund',
      'Satzkorn',
      'Schenkenhorst',
      'Seddiner See-Neuseddin',
      'Seeburg',
      'Stahnsdorf',
      'Teltow',
      'Töplitz' => ['Alt-Töplitz'],
      'Uetz',
      'Werder' => ['Bliesendorf', 'Plötzin'],
      'Wildenbruch',
      'Wilhelmshorst',
     ],

     'Teltow-Fläming',
     ['Großbeeren',
      'Ludwigsfelde' => ['Genshagen'],
      'Siethen',
     ],

    ];

%kfz = (qw(B   Berlin
	   BAR Barnim
	   HVL Havelland
	   OHV Oberhavelland
	   P   Potsdam
	   PM  Potsdam-Mittelmark
	   TF  Teltow-Fläming
	  ),
	LDS => 'Landkreis Dahme-Spree',
	LOS => 'Landkreis Oder-Spree',
	MOL => 'Märkisch Oderland',
       );

sub new {
    my($class) = @_;
    bless {}, $class;
}

1;

__END__
