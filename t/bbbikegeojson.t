#!/usr/bin/perl -w
# -*- perl -*-

#
# Author: Slaven Rezic
#

use strict;
use FindBin;
use lib "$FindBin::RealBin/..";

BEGIN {
    if (!eval q{
	use Test::More;
	1;
    }) {
	print "1..0 # skip no Test::More module\n";
	exit;
    }
}

use BBBikeGeoJSON;

plan tests => 2;

{
    # Created with:
    # http://localhost/bbbike/cgi/bbbike.cgi?startc=-15820%2C-1146&startname=Neues+Palais+%28Potsdam%29&startplz=&zielc=-12493%2C-1896&zielname=Potsdam+Hauptbahnhof+%28Potsdam%29&zielplz=&pref_seen=1&pref_speed=20&pref_cat=&pref_quality=&pref_green=&pref_specialvehicle=&scope=region&output_as=perldump
    my $route_sample = {
           'Route' => [
                        {
                          'DirectionHtml' => 'O',
                          'Comment' => 'Fußgänger haben Vorrang',
                          'Direction' => 'E',
                          'TotalDistString' => '',
                          'FragezeichenComment' => '',
                          'Dist' => 0,
                          'TotalDist' => 0,
                          'PathIndex' => 0,
                          'CommentHtml' => 'Fußgänger haben Vorrang',
                          'Angle' => undef,
                          'DirectionString' => 'O',
                          'ImportantAngleCrossingName' => undef,
                          'Coord' => '-15820,-1146',
                          'Strname' => '(Ökonomieweg, Sanssouci) (Potsdam)',
                          'DistString' => ''
                        },
                        {
                          'DirectionHtml' => '&#x21d2;',
                          'Comment' => 'Fußgänger haben Vorrang; Pflasterung (Teilstrecke)',
                          'Direction' => 'r',
                          'TotalDistString' => '1.0 km',
                          'FragezeichenComment' => '',
                          'Dist' => 957,
                          'TotalDist' => 957,
                          'PathIndex' => 4,
                          'CommentHtml' => 'Fußgänger haben Vorrang; Pflasterung (Teilstrecke)',
                          'Angle' => 70,
                          'DirectionString' => 'rechts (70°) in die',
                          'ImportantAngleCrossingName' => undef,
                          'Coord' => '-14865,-1118',
                          'Strname' => '((Ökonomieweg -) Lennéstr., Sanssouci) (Potsdam)',
                          'DistString' => '0.96 km'
                        },
                        {
                          'DirectionHtml' => '',
                          'Comment' => 'schlechtes Kopfsteinpflaster (Teilstrecke); Kopfsteinpflaster (Teilstrecke)',
                          'Direction' => '',
                          'TotalDistString' => '1.3 km',
                          'FragezeichenComment' => '',
                          'Dist' => 374,
                          'TotalDist' => 1331,
                          'PathIndex' => 6,
                          'CommentHtml' => 'schlechtes Kopfsteinpflaster (Teilstrecke); Kopfsteinpflaster (Teilstrecke)',
                          'Angle' => 20,
                          'DirectionString' => '',
                          'ImportantAngleCrossingName' => undef,
                          'Coord' => '-14614,-1342',
                          'Strname' => 'Lennéstr. (Potsdam)',
                          'DistString' => '0.37 km'
                        },
                        {
                          'DirectionHtml' => '&#x21d7;',
                          'Comment' => 'Kopfsteinpflaster',
                          'Direction' => 'hr',
                          'TotalDistString' => '1.8 km',
                          'FragezeichenComment' => '',
                          'Dist' => 474,
                          'TotalDist' => 1805,
                          'PathIndex' => 9,
                          'CommentHtml' => 'Kopfsteinpflaster',
                          'Angle' => 10,
                          'DirectionString' => 'halbrechts (10°) weiter auf der',
                          'ImportantAngleCrossingName' => 'Zimmerstr.',
                          'Coord' => '-14149,-1264',
                          'Strname' => 'Lennéstr. (Potsdam)',
                          'DistString' => '0.47 km'
                        },
                        {
                          'DirectionHtml' => '&#x21d0;',
                          'Comment' => '',
                          'Direction' => 'l',
                          'TotalDistString' => '2.2 km',
                          'FragezeichenComment' => '',
                          'Dist' => 441,
                          'TotalDist' => 2246,
                          'PathIndex' => 12,
                          'CommentHtml' => '',
                          'Angle' => 70,
                          'DirectionString' => 'links (70°) in die',
                          'ImportantAngleCrossingName' => undef,
                          'Coord' => '-13727,-1300',
                          'Strname' => '((Zeppelinstr. -) Charlottenstr.) (Potsdam)',
                          'DistString' => '0.44 km'
                        },
                        {
                          'DirectionHtml' => '&#x21d2;',
                          'Comment' => '',
                          'Direction' => 'r',
                          'TotalDistString' => '2.5 km',
                          'FragezeichenComment' => '',
                          'Dist' => 225,
                          'TotalDist' => 2471,
                          'PathIndex' => 14,
                          'CommentHtml' => '',
                          'Angle' => 100,
                          'DirectionString' => 'rechts (100°) in die',
                          'ImportantAngleCrossingName' => undef,
                          'Coord' => '-13516,-1225',
                          'Strname' => 'Schopenhauerstr. (Potsdam)',
                          'DistString' => '0.23 km'
                        },
                        {
                          'DirectionHtml' => '&#x21d0;',
                          'Comment' => '; Havelradweg; R1',
                          'Direction' => 'l',
                          'TotalDistString' => '2.8 km',
                          'FragezeichenComment' => '',
                          'Dist' => 292,
                          'TotalDist' => 2763,
                          'PathIndex' => 15,
                          'CommentHtml' => '; <a href="http://www.havelradweg.de/">Havelradweg</a>; <a href="http://www.euroroute-r1.de/">R1</a>',
                          'Angle' => 70,
                          'DirectionString' => 'links (70°) in die',
                          'ImportantAngleCrossingName' => undef,
                          'Coord' => '-13516,-1517',
                          'Strname' => 'Breite Str. (B1) (Potsdam)',
                          'DistString' => '0.29 km'
                        },
                        {
                          'DirectionHtml' => '',
                          'Comment' => 'beidseitiger Radweg vorhanden; Route Alter Fritz',
                          'Direction' => '',
                          'TotalDistString' => '3.5 km',
                          'FragezeichenComment' => '',
                          'Dist' => 768,
                          'TotalDist' => 3531,
                          'PathIndex' => 19,
                          'CommentHtml' => 'beidseitiger Radweg vorhanden; Route Alter Fritz',
                          'Angle' => 10,
                          'DirectionString' => '',
                          'ImportantAngleCrossingName' => undef,
                          'Coord' => '-12758,-1654',
                          'Strname' => 'Lange Brücke (Potsdam)',
                          'DistString' => '0.77 km'
                        },
                        {
                          'DirectionHtml' => 'angekommen!',
                          'Comment' => '',
                          'TotalDistString' => '3.9 km',
                          'Dist' => 365,
                          'TotalDist' => 3896,
                          'PathIndex' => '22',
                          'CommentHtml' => '',
                          'DirectionString' => 'angekommen!',
                          'Coord' => '-12493,-1896',
                          'Strname' => 'Potsdam Hauptbahnhof (Potsdam)',
                          'DistString' => '0.36 km'
                        }
                      ],
           'LongLatPath' => [
                              '13.014549,52.399747',
                              '13.017037,52.399801',
                              '13.018478,52.399767',
                              '13.026255,52.400069',
                              '13.028601,52.399845',
                              '13.028702,52.398900',
                              '13.032224,52.397791',
                              '13.033916,52.397782',
                              '13.035936,52.397922',
                              '13.039086,52.398418',
                              '13.043101,52.398383',
                              '13.044793,52.398401',
                              '13.045281,52.398027',
                              '13.046529,52.398418',
                              '13.048406,52.398667',
                              '13.048318,52.396042',
                              '13.050382,52.395759',
                              '13.052390,52.395530',
                              '13.056755,52.394979',
                              '13.059423,52.394689',
                              '13.060865,52.394260',
                              '13.062182,52.393194',
                              '13.063247,52.392472'
                            ],
           'Trafficlights' => 5,
           'AffectingBlockings' => [
                                     {
                                       'longlathop' => [
                                                         '13.014549,52.399747',
                                                         '13.017037,52.399801'
                                                       ],
                                       'hop' => [
                                                  '-15820,-1146',
                                                  '-15651,-1137'
                                                ],
                                       'recurring' => 1,
                                       'data' => '(Am Neuen Palais, direkter Weg) 	2::night -15810,-1274 -15820,-1146 -15854,-656
(Am Grünen Gitter, Sanssouci): Weg ist nur zwischen 6 Uhr bis zum Einbruch der Dunkelheit geöffnet 	2::night -13857,-1040 -14153,-1135 -14171,-1026
(Ökonomieweg, Sanssouci): Weg ist nur zwischen 6 Uhr bis zum Einbruch der Dunkelheit geöffnet 	2::night -14171,-1026 -14482,-1043 -14622,-1138 -14865,-1118 -15025,-1096 -15553,-1139 -15651,-1137 -15820,-1146
(Lennestr. - Ökonomieweg, Sanssouci): Weg ist nur zwischen 6 Uhr bis zum Einbruch der Dunkelheit geöffnet 	2::night -14614,-1342 -14856,-1223 -14865,-1118
(Affengang, Sanssouci): Weg ist nur zwischen 6 Uhr bis zum Einbruch der Dunkelheit geöffnet 	2::night -14129,-1258 -14131,-1181 -14153,-1135
',
                                       'net' => bless( {
                                                         'Strassen' => bless( {
                                                                                'Directives' => [],
                                                                                'DependentFiles' => [],
                                                                                'GlobalDirectives' => {},
                                                                                'Pos' => 5,
                                                                                'Data' => [
                                                                                            '(Am Neuen Palais, direkter Weg) 	2::night -15810,-1274 -15820,-1146 -15854,-656
',
                                                                                            '(Am Grünen Gitter, Sanssouci): Weg ist nur zwischen 6 Uhr bis zum Einbruch der Dunkelheit geöffnet 	2::night -13857,-1040 -14153,-1135 -14171,-1026
',
                                                                                            '(Ökonomieweg, Sanssouci): Weg ist nur zwischen 6 Uhr bis zum Einbruch der Dunkelheit geöffnet 	2::night -14171,-1026 -14482,-1043 -14622,-1138 -14865,-1118 -15025,-1096 -15553,-1139 -15651,-1137 -15820,-1146
',
                                                                                            '(Lennestr. - Ökonomieweg, Sanssouci): Weg ist nur zwischen 6 Uhr bis zum Einbruch der Dunkelheit geöffnet 	2::night -14614,-1342 -14856,-1223 -14865,-1118
',
                                                                                            '(Affengang, Sanssouci): Weg ist nur zwischen 6 Uhr bis zum Einbruch der Dunkelheit geöffnet 	2::night -14129,-1258 -14131,-1181 -14153,-1135
'
                                                                                          ]
                                                                              }, 'Strassen' ),
                                                         'Net2Name' => {},
                                                         'Net' => {
                                                                    '-14614,-1342' => {
                                                                                        '-14856,-1223' => '2'
                                                                                      },
                                                                    '-14482,-1043' => {
                                                                                        '-14622,-1138' => '2',
                                                                                        '-14171,-1026' => '2'
                                                                                      },
                                                                    '-13857,-1040' => {
                                                                                        '-14153,-1135' => '2'
                                                                                      },
                                                                    '-15820,-1146' => {
                                                                                        '-15854,-656' => '2',
                                                                                        '-15810,-1274' => '2',
                                                                                        '-15651,-1137' => '2'
                                                                                      },
                                                                    '-14171,-1026' => {
                                                                                        '-14482,-1043' => '2',
                                                                                        '-14153,-1135' => '2'
                                                                                      },
                                                                    '-14856,-1223' => {
                                                                                        '-14614,-1342' => '2',
                                                                                        '-14865,-1118' => '2'
                                                                                      },
                                                                    '-14622,-1138' => {
                                                                                        '-14482,-1043' => '2',
                                                                                        '-14865,-1118' => '2'
                                                                                      },
                                                                    '-15651,-1137' => {
                                                                                        '-15820,-1146' => '2',
                                                                                        '-15553,-1139' => '2'
                                                                                      },
                                                                    '-14129,-1258' => {
                                                                                        '-14131,-1181' => '2'
                                                                                      },
                                                                    '-15553,-1139' => {
                                                                                        '-15025,-1096' => '2',
                                                                                        '-15651,-1137' => '2'
                                                                                      },
                                                                    '-15025,-1096' => {
                                                                                        '-15553,-1139' => '2',
                                                                                        '-14865,-1118' => '2'
                                                                                      },
                                                                    '-14131,-1181' => {
                                                                                        '-14129,-1258' => '2',
                                                                                        '-14153,-1135' => '2'
                                                                                      },
                                                                    '-15854,-656' => {
                                                                                       '-15820,-1146' => '2'
                                                                                     },
                                                                    '-15810,-1274' => {
                                                                                        '-15820,-1146' => '2'
                                                                                      },
                                                                    '-14153,-1135' => {
                                                                                        '-13857,-1040' => '2',
                                                                                        '-14131,-1181' => '2',
                                                                                        '-14171,-1026' => '2'
                                                                                      },
                                                                    '-14865,-1118' => {
                                                                                        '-15025,-1096' => '2',
                                                                                        '-14856,-1223' => '2',
                                                                                        '-14622,-1138' => '2'
                                                                                      }
                                                                  }
                                                       }, 'StrassenNetz' ),
                                       'strobj' => bless( {
                                                            'Pos_Iterator_grepstreets' => 5,
                                                            'Directives' => [],
                                                            'GlobalDirectives' => {},
                                                            'Data' => [
                                                                        '(Am Neuen Palais, direkter Weg) 	2::night -15810,-1274 -15820,-1146 -15854,-656
',
                                                                        '(Am Grünen Gitter, Sanssouci): Weg ist nur zwischen 6 Uhr bis zum Einbruch der Dunkelheit geöffnet 	2::night -13857,-1040 -14153,-1135 -14171,-1026
',
                                                                        '(Ökonomieweg, Sanssouci): Weg ist nur zwischen 6 Uhr bis zum Einbruch der Dunkelheit geöffnet 	2::night -14171,-1026 -14482,-1043 -14622,-1138 -14865,-1118 -15025,-1096 -15553,-1139 -15651,-1137 -15820,-1146
',
                                                                        '(Lennestr. - Ökonomieweg, Sanssouci): Weg ist nur zwischen 6 Uhr bis zum Einbruch der Dunkelheit geöffnet 	2::night -14614,-1342 -14856,-1223 -14865,-1118
',
                                                                        '(Affengang, Sanssouci): Weg ist nur zwischen 6 Uhr bis zum Einbruch der Dunkelheit geöffnet 	2::night -14129,-1258 -14131,-1181 -14153,-1135
'
                                                                      ],
                                                            'Pos' => -1
                                                          }, 'Strassen' ),
                                       'lost_time' => {
                                                        '20' => undef
                                                      },
                                       'until' => undef,
                                       'index' => 1810,
                                       'text' => 'Sanssouci: Wege sind nur zwischen 6 Uhr bis zum Einbruch der Dunkelheit geöffnet',
                                       'from' => undef,
                                       'id' => 1810,
                                       'type' => 'gesperrt'
                                     }
                                   ],
           'Speed' => {
                        '25' => {
                                  'Time' => '0.156141208194474',
                                  'Pref' => ''
                                },
                        '10' => {
                                  'Time' => '0.390353020486184',
                                  'Pref' => ''
                                },
                        '20' => {
                                  'Time' => '0.195176510243092',
                                  'Pref' => 1
                                },
                        '15' => {
                                  'Time' => '0.260235346990789',
                                  'Pref' => ''
                                }
                      },
           'Session' => '1:cd000000_e82860ff67e620d4',
           'Len' => '3903.53020486184',
           'Path' => [
                       '-15820,-1146',
                       '-15651,-1137',
                       '-15553,-1139',
                       '-15025,-1096',
                       '-14865,-1118',
                       '-14856,-1223',
                       '-14614,-1342',
                       '-14499,-1341',
                       '-14362,-1323',
                       '-14149,-1264',
                       '-13876,-1263',
                       '-13761,-1259',
                       '-13727,-1300',
                       '-13643,-1255',
                       '-13516,-1225',
                       '-13516,-1517',
                       '-13375,-1546',
                       '-13238,-1569',
                       '-12940,-1625',
                       '-12758,-1654',
                       '-12659,-1700',
                       '-12567,-1817',
                       '-12493,-1896'
                     ],
           'Power' => {}
         };

    my $geojson_object = BBBikeGeoJSON::bbbikecgires_to_geojson_object($route_sample);
    #require Data::Dumper; diag(Data::Dumper->new([$geojson_object],[qw()])->Indent(1)->Useqq(1)->Dump); # XXX
    ok $geojson_object;
    my $geojson_json = BBBikeGeoJSON::bbbikecgires_to_geojson_json($route_sample);
    #diag $geojson_json;
    ok $geojson_json;
}

__END__
