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
     { from  => undef, # 
       until => undef, #
       text  => 'Hegemeisterweg/Treskowallee: Übergang kann wegen Bauarbeiten gesperrt sein',
       type  => 'gesperrt',
       data  => <<'EOF',
Treskowallee -> Hegemeisterweg	3::inwork 18256,7520 18382,7724 18325,7778
Hegemeisterweg -> Treskowallee	3::inwork 18325,7778 18382,7724 18406,7760
Treskowallee -> Hegemeisterweg	3::inwork 18382,7724 18406,7760 18325,7778
Treskowallee -> Modellpark Wuhlheide	3::inwork 18471,7862 18406,7760 18437,7752
Hegemeisterweg -> Treskowallee	3::inwork 18325,7778 18406,7760 18471,7862
Hegemeisterweg -> Modellpark Wuhlheide	3::inwork 18325,7778 18406,7760 18437,7752
Modellpark Wuhlheide -> Treskowallee	3::inwork 18437,7752 18406,7760 18382,7724
Modellpark Wuhlheide -> Hegemeisterweg	3::inwork 18437,7752 18406,7760 18325,7778
EOF
     },
    );
