# -*- perl -*-

package [% bundle_module %];

$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

1;

__END__
[%
    SWITCH type;
        CASE "full";
            SET shortname = "all";
        CASE "small";
	    SET shortname = "only mandatory";
	CASE "cgi";
	    SET shortname = "cgi";
	CASE "windist";
	    SET shortname = "windows distribution";
	CASE "";
	    SET shortname = "! missing setting type in Template call in Makefile.PL !";
	CASE;
	    SET shortname = "! missing shortname !";
    END;
%]
=head1 NAME

[% bundle_module %] - A bundle to install [% shortname %] dependencies of BBBike

=head1 SYNOPSIS

 perl -I`pwd` -MCPAN -e 'install [% bundle_module %]'

=head1 CONTENTS

[% modules_string -%]

=head1 DESCRIPTION

[% IF type == "full" -%]
Dieses BE<uuml>ndel listet alle erforderlichen und empfohlenen Module
fE<uuml>r BBBike auf. Bis auf B<Tk> sind alle anderen Module optional.

This bundle lists all required and optional perl modules for BBBike.
Only B<Tk> is really required, all other modules are optional.
[% ELSIF type == "small" -%]
Dieses BE<uuml>ndel listet nur die notwendigen Module
fE<uuml>r BBBike auf.

This bundle lists only mandatory perl modules for BBBike.
[% ELSIF type == "cgi" -%]
Module für eine CGI-Installation.
[% ELSIF type == "windist" -%]
Module für die binäre Windows-Distribution.
[% ELSE -%]
!!! Description missing for bundle type [% type %]. Please edit Bundle/BBBike.tpl.pm !!!
[% END -%]

=head1 AUTHOR

Slaven Rezic <slaven@rezic.de>

=cut
