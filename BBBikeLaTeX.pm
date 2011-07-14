# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2011 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeLaTeX;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

BEGIN {
    if (!eval '
use Msg qw(frommain);
1;
') {
	warn $@ if $@;
	eval 'sub M ($) { $_[0] }';
	eval 'sub Mfmt { sprintf(shift, @_) }';
    }
}

sub route_info_to_latex {
    my(%args) = @_;
    my $route_title = $args{-routetitle};
    my $route_info  = $args{-routeinfo};

    my $coding = 'latin1';
 FIND_CODING: {
	my $needs_unicode;
	for ($route_title, (map { $_->[3] } @$route_info)) {
	    if (m{\p{Cyrillic}}) {
		$coding = 'cyrillic';
		last FIND_CODING;
	    }
	    if (m{[^\0-\xff]}) {
		$needs_unicode = 1;
	    }
	}
    	if ($needs_unicode) {
	    $coding = 'unicode';
	}
    }

    _route_info_to_latex(%args, -coding => $coding);
}

# More tweaking could be done (other font face/size, real wide margins...)
sub _route_info_to_latex {
    my(%args) = @_;
    my $route_title = exists $args{-routetitle} ? delete $args{-routetitle} : die "-routetitle is missing";
    my $route_info  = exists $args{-routeinfo}  ? delete $args{-routeinfo}  : die "-routeinfo is missing";
    my $coding      = exists $args{-coding}     ? delete $args{-coding}     : 'latin1';
    die "Unhandled arguments: " . join(" ", %args) if %args;

    # escape for latex missing XXX
    my $latex;
    $latex .= <<'EOF';
\documentclass[10pt]{article}
EOF

    if ($coding eq 'latin1') {
	$latex .= <<'EOF';
\usepackage[latin1]{inputenc}
\usepackage{german}
EOF
    } else {
	my $language = $coding eq 'cyrillic' ? 'bulgarian' : 'english';
	$latex .= <<'EOF';
\usepackage[utf8x]{inputenc}
% bad results: \SetUnicodeOption{combine}
EOF
	$latex .= <<"EOF";
\\usepackage[$language]{babel}
EOF
    }

    $latex .= <<'EOF';
\usepackage[widemargins]{a4}
\usepackage{supertabular}
\pagestyle{empty}
% Tip from http://www.mackichan.com/index.html?techtalk/579.htm~mainFrame
% and http://www.faqs.org/faqs/de-tex-faq/part10/ (10.2.2)
\usepackage{helvet}
\renewcommand{\familydefault}{\sfdefault}
\sloppy
\begin{document}
EOF
    $latex .= "\\section*{$route_title}\n";
    $latex .= <<'EOF';
\begin{supertabular}{lllp{8cm}}
EOF
    $latex .= join(" & ", M"Länge", M"Gesamt", M"Richtung", M"Straße") . "\\\\\n";
    $latex .= "\\hline \\\\\n";

    $latex .= join "", map {
	join(" & ", map { s/=>/\$\\rightarrow{}\$/g; $_ } @$_) . "\\\\\n"
    } @$route_info;
    $latex .= <<'EOF';
\end{supertabular}
\end{document}
EOF

    if ($coding eq 'latin1') {
	$latex;
    } else {
	require Encode;
	Encode::encode("utf-8", $latex); # from this point we have always octets!
    }
}

1;

__END__
