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
use Route;

plan tests => 11;

{
    # Created with:
    # http://localhost/bbbike/cgi/bbbike.cgi?startc=-15820%2C-1146&startname=Neues+Palais+%28Potsdam%29&startplz=&zielc=-12493%2C-1896&zielname=Potsdam+Hauptbahnhof+%28Potsdam%29&zielplz=&pref_seen=1&pref_speed=20&pref_cat=&pref_quality=&pref_green=&pref_specialvehicle=&scope=region&output_as=perldump
    my $route_sample = {
           'Route' => [
                        {
                          'DirectionHtml' => 'nach Osten',
                          'Comment' => 'Fußgänger haben Vorrang',
                          'Direction' => 'E',
                          'TotalDistString' => '',
                          'FragezeichenComment' => '',
                          'Dist' => 0,
                          'TotalDist' => 0,
                          'LongLatCoord' => '13.014549,52.399747',
                          'PathIndex' => 0,
                          'CommentHtml' => 'Fußgänger haben Vorrang',
                          'Angle' => undef,
                          'DirectionString' => 'nach Osten',
                          'ImportantAngleCrossingName' => undef,
                          'Coord' => '-15820,-1146',
                          'Strname' => '(Ökonomieweg, Sanssouci) (Potsdam)',
                          'DistString' => ''
                        },
                        {
                          'DirectionHtml' => 'rechts (70°) in die',
                          'Comment' => 'Fußgänger haben Vorrang; Pflasterung (Teilstrecke)',
                          'Direction' => 'r',
                          'TotalDistString' => '1.0 km',
                          'FragezeichenComment' => '',
                          'Dist' => 957,
                          'TotalDist' => 957,
                          'LongLatCoord' => '13.028601,52.399845',
                          'PathIndex' => 4,
                          'CommentHtml' => 'Fußgänger haben Vorrang; Pflasterung (Teilstrecke)',
                          'Angle' => 70,
                          'DirectionString' => 'rechts (70°) in die',
                          'ImportantAngleCrossingName' => undef,
                          'Coord' => '-14865,-1118',
                          'Strname' => '((Ökonomieweg -) Lennéstr., Sanssouci) (Potsdam)',
                          'DistString' => 'nach 0.96 km'
                        },
                        {
                          'DirectionHtml' => '',
                          'Comment' => 'schlechtes Kopfsteinpflaster (Teilstrecke); Kopfsteinpflaster (Teilstrecke)',
                          'Direction' => '',
                          'TotalDistString' => '1.3 km',
                          'FragezeichenComment' => '',
                          'Dist' => 374,
                          'TotalDist' => 1331,
                          'LongLatCoord' => '13.032224,52.397791',
                          'PathIndex' => 6,
                          'CommentHtml' => 'schlechtes Kopfsteinpflaster (Teilstrecke); Kopfsteinpflaster (Teilstrecke)',
                          'Angle' => 20,
                          'DirectionString' => '',
                          'ImportantAngleCrossingName' => undef,
                          'Coord' => '-14614,-1342',
                          'Strname' => 'Lennéstr. (Potsdam)',
                          'DistString' => 'nach 0.37 km'
                        },
                        {
                          'DirectionHtml' => 'halbrechts (20°) in die',
                          'Comment' => 'geteert, aber mit Straßenschäden',
                          'Direction' => 'hr',
                          'TotalDistString' => '1.6 km',
                          'FragezeichenComment' => '',
                          'Dist' => 253,
                          'TotalDist' => 1584,
                          'LongLatCoord' => '13.035936,52.397922',
                          'PathIndex' => 8,
                          'CommentHtml' => 'geteert, aber mit Straßenschäden',
                          'Angle' => 20,
                          'DirectionString' => 'halbrechts (20°) in die',
                          'ImportantAngleCrossingName' => undef,
                          'Coord' => '-14362,-1323',
                          'Strname' => 'Feuerbachstr. (Potsdam)',
                          'DistString' => 'nach 0.25 km'
                        },
                        {
                          'DirectionHtml' => '',
                          'Comment' => 'F1 (Potsdam) (Teilstrecke); R1 (Teilstrecke); Havelradweg (Teilstrecke)',
                          'Direction' => '',
                          'TotalDistString' => '2.1 km',
                          'FragezeichenComment' => '',
                          'Dist' => 498,
                          'TotalDist' => 2082,
                          'LongLatCoord' => '13.043002,52.396748',
                          'PathIndex' => 11,
                          'CommentHtml' => 'F1 (Potsdam) (Teilstrecke); <a href="http://www.euroroute-r1.de/">R1 (Teilstrecke)</a>; <a href="http://www.havelradweg.de/">Havelradweg (Teilstrecke)</a>',
                          'Angle' => 0,
                          'DirectionString' => '',
                          'ImportantAngleCrossingName' => undef,
                          'Coord' => '-13879,-1445',
                          'Strname' => 'Breite Str. (B1) (Potsdam)',
                          'DistString' => 'nach 0.50 km'
                        },
                        {
                          'DirectionHtml' => 'halbrechts (30°) auf die',
                          'Comment' => 'Route Alter Fritz; Radweg auf der westlichen Seite sowie Zweirichtungsradweg auf der östlichen Seite',
                          'Direction' => 'hr',
                          'TotalDistString' => '3.2 km',
                          'FragezeichenComment' => '',
                          'Dist' => 1137,
                          'TotalDist' => 3219,
                          'LongLatCoord' => '13.059423,52.394689',
                          'PathIndex' => 17,
                          'CommentHtml' => 'Route Alter Fritz; Radweg auf der westlichen Seite sowie Zweirichtungsradweg auf der östlichen Seite',
                          'Angle' => 30,
                          'DirectionString' => 'halbrechts (30°) auf die',
                          'ImportantAngleCrossingName' => undef,
                          'Coord' => '-12758,-1654',
                          'Strname' => 'Lange Brücke (Potsdam)',
                          'DistString' => 'nach 1.14 km'
                        },
                        {
                          'DirectionHtml' => 'angekommen!',
                          'Comment' => '',
                          'TotalDistString' => '3.6 km',
                          'Dist' => 367,
                          'TotalDist' => 3586,
                          'LongLatCoord' => '13.063247,52.392472',
                          'PathIndex' => 21,
                          'CommentHtml' => '',
                          'DirectionString' => 'angekommen!',
                          'Coord' => '-12493,-1896',
                          'Strname' => 'Potsdam Hauptbahnhof (Potsdam)',
                          'DistString' => 'nach 0.37 km'
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
                              '13.037671,52.397471',
                              '13.039180,52.397284',
                              '13.043002,52.396748',
                              '13.044688,52.396594',
                              '13.048318,52.396042',
                              '13.050382,52.395759',
                              '13.052390,52.395530',
                              '13.056755,52.394979',
                              '13.059423,52.394689',
                              '13.059826,52.394442',
                              '13.060865,52.394260',
                              '13.062182,52.393194',
                              '13.063247,52.392472'
                            ],
           'Trafficlights' => 5,
           'AffectingBlockings' => [
                                     {
                                       'Type' => 'gesperrt',
                                       'Index' => 1810,
                                       'Recurring' => 1,
                                       'LongLatHop' => {
                                                         'XY' => [
                                                                   '13.014549,52.399747',
                                                                   '13.017037,52.399801'
                                                                 ]
                                                       },
                                       'Text' => 'Sanssouci: Wege sind nur zwischen 6 Uhr bis zum Einbruch der Dunkelheit geöffnet'
                                     }
                                   ],
           'Speed' => {
                        '25' => {
                                  'Time' => '0.164707020125922',
                                  'Pref' => ''
                                },
                        '10' => {
                                  'Time' => '0.380517550314806',
                                  'Pref' => ''
                                },
                        '20' => {
                                  'Time' => '0.200675441824069',
                                  'Pref' => '1'
                                },
                        '15' => {
                                  'Time' => '0.260622811320982',
                                  'Pref' => ''
                                }
                      },
           'Session' => 'ce000000_00dde8383c4d03ad',
           'Len' => '3596.84216981472',
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
                       '-14243,-1371',
                       '-14140,-1390',
                       '-13879,-1445',
                       '-13764,-1460',
                       '-13516,-1517',
                       '-13375,-1546',
                       '-13238,-1569',
                       '-12940,-1625',
                       '-12758,-1654',
                       '-12730,-1681',
                       '-12659,-1700',
                       '-12567,-1817',
                       '-12493,-1896'
                     ],
           'Power' => {}
         };

    {
	my $geojson_object = BBBikeGeoJSON::bbbikecgires_to_geojson_object($route_sample);
	#require Data::Dumper; diag(Data::Dumper->new([$geojson_object],[qw()])->Indent(1)->Useqq(1)->Dump); # XXX
	ok $geojson_object;
	is $geojson_object->{properties}->{type}, 'Route';
	isa_ok $geojson_object->{properties}->{result}->{Route}, 'ARRAY', 'Found route array in long result'; 
    }

    {
	my $geojson_object = BBBikeGeoJSON::bbbikecgires_to_geojson_object($route_sample, short => 1);
	#require Data::Dumper; diag(Data::Dumper->new([$geojson_object],[qw()])->Indent(1)->Useqq(1)->Dump); # XXX
	ok $geojson_object;
	is $geojson_object->{properties}->{type}, 'Route';
	ok !$geojson_object->{properties}->{result}, 'short result'; 
    }

    {
	my $geojson_json = BBBikeGeoJSON::bbbikecgires_to_geojson_json($route_sample);
	#diag $geojson_json;
	ok $geojson_json;
    }

    {
	my $route = Route->new_from_realcoords([[0,0],[100,100],[200,100]]);
	my $geojson_object = BBBikeGeoJSON::route_to_geojson_object($route);
	my($lon,$lat) = @{ $geojson_object->{geometry}->{coordinates}->[0] };
	cmp_ok $lon, ">=", 13.247;
	cmp_ok $lon, "<=", 13.248;
	cmp_ok $lat, ">=", 52.407;
	cmp_ok $lat, "<=", 52.408;
    }
}

__END__
