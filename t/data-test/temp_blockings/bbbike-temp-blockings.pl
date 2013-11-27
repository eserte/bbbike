# -*- bbbike -*-
@temp_blocking =
    (
     { from  => undef, #
       until => undef, #
       text  => 'Maybachufer: Di und Fr 11.00-18.30 Wochenmarkt, Behinderungen möglich',
       type  => 'gesperrt',
       permanent => 1,
       data  => <<EOF,
	q4::temp 11543,10015 11669,9987 11880,9874
EOF
     },
     { from  => undef, #
       until => undef, #
       text  => 'Voltairestr.: Weihnachtsmarkt',
       type  => 'gesperrt',
       data  => <<EOF,
	2::temp 11209,12430 11329,12497
EOF
     },
     { from  => undef, #
       until => undef, #
       text  => 'Stralauer Str.: Bauarbeiten',
       type  => 'gesperrt',
       data  => <<EOF,
	1::temp 11221,12250 11300,12241
EOF
     },
    );
