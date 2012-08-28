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
    );
