# -*- perl -*-

package [% bundle_module %];

$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

1;

__END__

=head1 NAME

Bundle::BBBike - A bundle to install [% IF type == "full" %]all[% ELSIF type == "small" %]only mandatory[% ELSE %]radzeit[% END %] dependencies of BBBike

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
[% ELSIF type == "radzeit" -%]
Module für die Installation auf radzeit.de.
[% ELSE -%]
!!! Description missing for bundle type [% type %] !!!
[% END -%]

=head1 AUTHOR

Slaven Rezic <slaven@rezic.de>

=cut
