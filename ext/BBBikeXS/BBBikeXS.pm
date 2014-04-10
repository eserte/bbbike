package BBBikeXS;

# "use BBBikeXS" sollte *nach* use Strassen, use BBBikeTrans etc.
# ausgeführt werden, damit das Override der Perl-Funktionen durch die
# XS-Funktionen funktioniert.

# Warnung: XS ist anscheinend von 5.00503 nach 5.5.640 *nicht* kompatibel
# In diesem Falle gibt es einen Absturz (Floating exception).
# XXX Noch keinen Workaround zur Lösung des Problems gefunden.

use strict;
use vars qw($VERSION @ISA);

require DynaLoader;

@ISA     = qw(DynaLoader);
$VERSION = '0.12';

eval {
    local $SIG{__DIE__};
    bootstrap BBBikeXS $VERSION;
};
if ($@) {
#    warn $@;
    return 1;
}

package Strassen;
{
    local($^W) = 0;
    *to_koord = \&to_koord_XS;
    *to_koord1 = \&to_koord1_XS;
    *to_koord_f = \&to_koord_f_XS;
    *to_koord_f1 = \&to_koord_f1_XS;
}

{
    local($^W) = 0;
    *StrassenNetz::make_net_PP = \&StrassenNetz::make_net;
    if ($StrassenNetz::data_format == $StrassenNetz::FMT_HASH) {
	*StrassenNetz::make_net    = \&StrassenNetz::make_net_XS;
	*StrassenNetz::make_net_classic = \&StrassenNetz::make_net_XS;
    }
}

package main;
{
    local($^W) = 0;
    *transpose_ls = \&transpose_ls_XS;
}

{
    local $^W = 0;
    *Strassen::Util::strecke_PP = \&Strassen::Util::strecke;
    # Warning: no checks with the XS version!
    *Strassen::Util::strecke    = \&Strassen::Util::strecke_XS;

    *Strassen::Util::strecke_s_PP = \&Strassen::Util::strecke_s;
    *Strassen::Util::strecke_s    = \&Strassen::Util::strecke_s_XS;
}

1;
__END__
