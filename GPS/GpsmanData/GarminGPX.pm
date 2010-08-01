# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2010 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package GPS::GpsmanData::GarminGPX;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

######################################################################
use vars qw(%gpsman_symbol_name_to_garmin_id);
%gpsman_symbol_name_to_garmin_id =
# Generated with:
#
#    perl -nle '/array set SYMBOLCODE \{/../\}/ and push @l, $_; END { print @l[1..$#l-1] }' /usr/local/share/gpsman/gmsrc/garmin_symbols.tcl > /tmp/gpsman2garmin
#
qw(
anchor 0 bell 1 diamond_green 2 diamond_red 3 diver_down_1 4
diver_down_2 5 dollar 6 fish 7 fuel 8 horn 9 house 10 knife_fork 11
light 12 mug 13 skull 14 square_green 15 square_red 16 WP_buoy_white
17 WP_dot 18 wreck 19 null 20 MOB 21 buoy_amber 22 buoy_black 23
buoy_blue 24 buoy_green 25 buoy_green_red 26 buoy_green_white 27
buoy_orange 28 buoy_red 29 buoy_red_green 30 buoy_red_white 31
buoy_violet 32 buoy_white 33 buoy_white_green 34 buoy_white_red 35 dot
36 radio_beacon 37 boat_ramp 150 camping 151 restrooms 152 showers 153
drinking_water 154 phone 155 1st_aid 156 info 157 parking 158 park 159
picnic 160 scenic 161 skiing 162 swimming 163 dam 164 controlled 165
danger 166 restricted 167 null_2 168 ball 169 car 170 deer 171
shopping_cart 172 lodging 173 mine 174 trail_head 175 truck_stop 176
exit 177 flag 178 circle_x 179 open_24hr 180 fhs_facility 181 bot_cond
182 tide_pred_stn 183 anchor_prohib 184 beacon 185 coast_guard 186
reef 187 weedbed 188 dropoff 189 dock 190 marina 191 bait_tackle 192
stump 193 is_highway 8192 us_highway 8193 st_highway 8194 mile_marker
8195 traceback 8196 golf 8197 small_city 8198 medium_city 8199
large_city 8200 freeway 8201 ntl_highway 8202 capitol_city 8203
amusement_park 8204 bowling 8205 car_rental 8206 car_repair 8207
fastfood 8208 fitness 8209 movie 8210 museum 8211 pharmacy 8212 pizza
8213 post_office 8214 RV_park 8215 school 8216 stadium 8217 store 8218
zoo 8219 fuel_store 8220 theater 8221 ramp_int 8222 street_int 8223
weight_station 8226 toll 8227 elevation 8228 exit_no_serv 8229
geo_name_man 8230 geo_name_water 8231 geo_name_land 8232 bridge 8233
building 8234 cemetery 8235 church 8236 civil 8237 crossing 8238
monument 8239 levee 8240 military 8241 oil_field 8242 tunnel 8243
beach 8244 tree 8245 summit 8246 large_ramp_int 8247 large_exit_ns
8248 police 8249 casino 8250 snow_skiing 8251 ice_skating 8252
tow_truck 8253 border 8254 geocache 8255 geocache_fnd 8256
cntct_smiley 8257 cntct_ball_cap 8258 cntct_big_ears 8259 cntct_spike
8260 cntct_goatee 8261 cntct_afro 8262 cntct_dreads 8263 cntct_female1
8264 cntct_female2 8265 cntct_female3 8266 cntct_ranger 8267
cntct_kung_fu 8268 cntct_sumo 8269 cntct_pirate 8270 cntct_biker 8271
cntct_alien 8272 cntct_bug 8273 cntct_cat 8274 cntct_dog 8275
cntct_pig 8276 hydrant 8282 flag_pin_blue 8284 flag_pin_green 8285
flag_pin_red 8286 pin_blue 8287 pin_green 8288 pin_red 8289 box_blue
8290 box_green 8291 box_red 8292 biker 8293 circle_red 8294
circle_green 8295 circle_blue 8296 diamond_blue 8299 oval_red 8300
oval_green 8301 oval_blue 8302 rect_red 8303 rect_green 8304 rect_blue
8305 square_blue 8308 letter_a_red 8309 letter_b_red 8310 letter_c_red
8311 letter_d_red 8312 letter_a_green 8313 letter_c_green 8314
letter_b_green 8315 letter_d_green 8316 letter_a_blue 8317
letter_b_blue 8318 letter_c_blue 8319 letter_d_blue 8320 number_0_red
8321 number_1_red 8322 number_2_red 8323 number_3_red 8324
number_4_red 8325 number_5_red 8326 number_6_red 8327 number_7_red
8328 number_8_red 8329 number_9_red 8330 number_0_green 8331
number_1_green 8332 number_2_green 8333 number_3_green 8334
number_4_green 8335 number_5_green 8336 number_6_green 8337
number_7_green 8338 number_8_green 8339 number_9_green 8340
number_0_blue 8341 number_1_blue 8342 number_2_blue 8343 number_3_blue
8344 number_4_blue 8345 number_5_blue 8346 number_6_blue 8347
number_7_blue 8348 number_8_blue 8349 number_9_blue 8350 triangle_blue
8351 triangle_green 8352 triangle_red 8353 airport 16384 intersection
16385 avn_ndb 16386 avn_vor 16387 heliport 16388 private 16389
soft_field 16390 tall_tower 16391 short_tower 16392 glider 16393
ultralight 16394 parachute 16395 avn_vortac 16396 avn_vordme 16397
avn_faf 16398 avn_lom 16399 avn_map 16400 avn_tacan 16401 seaplane
16402
); # until here

######################################################################
use vars qw(%garmin_id_to_garmin_gpx_symbol_name);
%garmin_id_to_garmin_gpx_symbol_name = (
# Generated with:
#
#    xmlgrep '//wpt' -e 'fv("cmt") =~ m{PCX:(\d+)} and int($1) . " => \"".fv("sym")."\","' /usr/local/src/work/gpsbabel/reference/garmin_symbols.gpx |sort -n -u > /tmp/garminidtoname
#
0 => "Anchor",
1 => "Bell",
2 => "Diamond, Green",
3 => "Diamond, Red",
4 => "Diver Down Flag 1",
5 => "Diver Down Flag 2",
6 => "Bank",
7 => "Fishing Area",
8 => "Gas Station",
9 => "Horn",
10 => "Residence",
11 => "Restaurant",
12 => "Light",
13 => "Bar",
14 => "Skull and Crossbones",
15 => "Square, Green",
16 => "Square, Red",
17 => "Buoy, White",
18 => "Waypoint",
19 => "Shipwreck",
21 => "Man Overboard",
22 => "Navaid, Amber",
23 => "Navaid, Black",
24 => "Navaid, Blue",
25 => "Navaid, Green",
26 => "Navaid, Green/Red",
27 => "Navaid, Green/White",
28 => "Navaid, Orange",
29 => "Navaid, Red",
30 => "Navaid, Red/Green",
31 => "Navaid, Red/White",
32 => "Navaid, Violet",
33 => "Navaid, White",
34 => "Navaid, White/Green",
35 => "Navaid, White/Red",
36 => "Dot, White",
37 => "Radio Beacon",
150 => "Boat Ramp",
151 => "Campground",
152 => "Restroom",
153 => "Shower",
155 => "Telephone",
156 => "Medical Facility",
157 => "Information",
158 => "Parking Area",
159 => "Park",
160 => "Picnic Area",
161 => "Scenic Area",
162 => "Skiing Area",
163 => "Swimming Area",
164 => "Dam",
165 => "Controlled Area",
166 => "Danger Area",
167 => "Restricted Area",
169 => "Ball Park",
170 => "Car",
171 => "Hunting Area",
172 => "Shopping Center",
173 => "Lodging",
174 => "Mine",
175 => "Trail Head",
176 => "Truck Stop",
177 => "Exit",
178 => "Flag",
179 => "Circle with X",
181 => "Fishing Hot Spot Facility",
184 => "Anchor Prohibited",
185 => "Beacon",
186 => "Coast Guard",
187 => "Reef",
188 => "Weed Bed",
189 => "Dropoff",
190 => "Dock",
191 => "Marina",
192 => "Bait and Tackle",
193 => "Stump",
7680 => "Custom 0",
7681 => "Custom 1",
7682 => "Custom 2",
7683 => "Custom 3",
7684 => "Custom 4",
7685 => "Custom 5",
7686 => "Custom 6",
7687 => "Custom 7",
8195 => "Mile Marker",
8196 => "TracBack Point",
8197 => "Golf Course",
8198 => "City (Small)",
8199 => "City (Medium)",
8200 => "City (Large)",
8203 => "City (Capitol)",
8204 => "Amusement Park",
8205 => "Bowling",
8206 => "Car Rental",
8207 => "Car Repair",
8208 => "Fast Food",
8209 => "Fitness Center",
8210 => "Movie Theater",
8211 => "Museum",
8212 => "Pharmacy",
8213 => "Pizza",
8214 => "Post Office",
8215 => "RV Park",
8216 => "School",
8217 => "Stadium",
8218 => "Department Store",
8219 => "Zoo",
8220 => "Convenience Store",
8221 => "Live Theater",
8226 => "Scales",
8227 => "Toll Booth",
8233 => "Bridge",
8234 => "Building",
8235 => "Cemetery",
8236 => "Church",
8237 => "Civil",
8238 => "Crossing",
8239 => "Ghost Town",
8240 => "Levee",
8241 => "Military",
8242 => "Oil Field",
8243 => "Tunnel",
8244 => "Beach",
8245 => "Forest",
8246 => "Summit",
8249 => "Police Station",
8251 => "Ski Resort",
8252 => "Ice Skating",
8253 => "Wrecker",
8255 => "Geocache",
8256 => "Geocache Found",
8257 => "Contact, Smiley",
8258 => "Contact, Ball Cap",
8259 => "Contact, Big Ears",
8260 => "Contact, Spike",
8261 => "Contact, Goatee",
8262 => "Contact, Afro",
8263 => "Contact, Dreadlocks",
8264 => "Contact, Female1",
8265 => "Contact, Female2",
8266 => "Contact, Female3",
8267 => "Contact, Ranger",
8268 => "Contact, Kung-Fu",
8269 => "Contact, Sumo",
8270 => "Contact, Pirate",
8271 => "Contact, Biker",
8272 => "Contact, Alien",
8273 => "Contact, Bug",
8274 => "Contact, Cat",
8275 => "Contact, Dog",
8276 => "Contact, Pig",
8282 => "Water Hydrant",
8284 => "Flag, Blue",
8285 => "Flag, Green",
8286 => "Flag, Red",
8287 => "Pin, Blue",
8288 => "Pin, Green",
8289 => "Pin, Red",
8290 => "Block, Blue",
8291 => "Block, Green",
8292 => "Block, Red",
8293 => "Bike Trail",
8294 => "Circle, Red",
8295 => "Circle, Green",
8296 => "Circle, Blue",
8299 => "Diamond, Blue",
8300 => "Oval, Red",
8301 => "Oval, Green",
8302 => "Oval, Blue",
8303 => "Rectangle, Red",
8304 => "Rectangle, Green",
8305 => "Rectangle, Blue",
8308 => "Square, Blue",
8309 => "Letter A, Red",
8310 => "Letter B, Red",
8311 => "Letter C, Red",
8312 => "Letter D, Red",
8313 => "Letter A, Green",
8314 => "Letter C, Green",
8315 => "Letter B, Green",
8316 => "Letter D, Green",
8317 => "Letter A, Blue",
8318 => "Letter B, Blue",
8319 => "Letter C, Blue",
8320 => "Letter D, Blue",
8321 => "Number 0, Red",
8322 => "Number 1, Red",
8323 => "Number 2, Red",
8324 => "Number 3, Red",
8325 => "Number 4, Red",
8326 => "Number 5, Red",
8327 => "Number 6, Red",
8328 => "Number 7, Red",
8329 => "Number 8, Red",
8330 => "Number 9, Red",
8331 => "Number 0, Green",
8332 => "Number 1, Green",
8333 => "Number 2, Green",
8334 => "Number 3, Green",
8335 => "Number 4, Green",
8336 => "Number 5, Green",
8337 => "Number 6, Green",
8338 => "Number 7, Green",
8339 => "Number 8, Green",
8340 => "Number 9, Green",
8341 => "Number 0, Blue",
8342 => "Number 1, Blue",
8343 => "Number 2, Blue",
8344 => "Number 3, Blue",
8345 => "Number 4, Blue",
8346 => "Number 5, Blue",
8347 => "Number 6, Blue",
8348 => "Number 7, Blue",
8349 => "Number 8, Blue",
8350 => "Number 9, Blue",
8351 => "Triangle, Blue",
8352 => "Triangle, Green",
8353 => "Triangle, Red",
16384 => "Airport",
16388 => "Heliport",
16389 => "Private Field",
16390 => "Soft Field",
16391 => "Tall Tower",
16392 => "Short Tower",
16393 => "Glider Area",
16394 => "Ultralight Area",
16395 => "Parachute Area",
16402 => "Seaplane Base",
# until here
);

# XXX The user defined symbols; currently hardcoded to the bike2008 set
my $garmin_user_id_to_name;
sub _setup_garmin_user_id_to_name {
    if (!$garmin_user_id_to_name) {
	$garmin_user_id_to_name = {};
	require BBBikeUtil;
	my $userdef_symbol_mapping = BBBikeUtil::bbbike_root()."/misc/garmin_userdef_symbols/bike2008/mapping";
	my $fh;
	if (!open $fh, $userdef_symbol_mapping) {
	    warn "Cannot open $userdef_symbol_mapping: $!";
	    return;
	}
	while(<$fh>) {
	    chomp;
	    next if m{^$} || m{^#};
	    my($iconname, $label) = split /\t/, $_, 2;
	    if (my($id) = $iconname =~ m{^(\d+)\.bmp$}) {
		$id += 7680;
		$garmin_user_id_to_name->{$id} = $label;
	    } else {
		warn "Cannot parse line $_ in $userdef_symbol_mapping, ignoring...";
	    }
	}
    }
}

sub gpsman_symbol_to_garmin_symbol_name {
    my($gpsman_symbol) = @_;
    if ($gpsman_symbol =~ m{^user:(\d+)$}) {
	my $user_id = $1;
	_setup_garmin_user_id_to_name();
	return $garmin_user_id_to_name->{$user_id};
    } else {
	my $id = $gpsman_symbol_name_to_garmin_id{$gpsman_symbol};
	return if !defined $id;
	my $name = $garmin_id_to_garmin_gpx_symbol_name{$id};
	$name;
    }
}

1;

__END__
