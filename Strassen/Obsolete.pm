# -*- perl -*-

#
# $Id: Obsolete.pm,v 1.1 2004/01/10 23:41:13 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package Strassen::Obsolete;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

package StrassenNetz;

sub build_search_code_srt {
    # XXX Not tested since migrating to Obsolete.pm
    my($self, $code, $sc, $seen_optimierung, $use_2, $do_visual, $penalty_code, $len_pen, $skip_path_code, $skip_path_code2, $pure_depth, $backtracking, $cut_path_nr, $argsref, $aufschlag_code) = @_;
    my %args = %$argsref;

    # XXX skip_path_code3: Dieser Code sollte im SRT-Algorithmus verwendet werden, wird aber
    # nicht...
    ######################################################################
    # SRT-Algo - nur von historischem Interesse...

    # Format von $path_def:
    # 0: Referenz auf Pfad
    # 1: derzeitige Länge
    # 2: virtuelle Penalty (ab hier einschließlich nur wenn
    #                       $sc->HasPenalty wahr ist)
    # 3: wahre Penalty
    # 4: Anzahl der Ampeln auf der Strecke (falls Ampeln eingestellt wurden)

    # Algorithm_Init
    $code .= '
    my @all_paths =
      (
       [[$from], 0';
    if ($sc->HasPenalty) {
	$code .= ', undef, 0';
	if ($sc->HasAmpeln) {
	    $code .= ', 0';
	}
    }
    if ($seen_optimierung) {
	$code .= ', {}';
    }

    $code .= '],
      );
    my(@found_paths, @suspended_paths);
    my %visited = ( $from => 0 );
BIGLOOP:
    while (1) {
';
    if ($sc->Statistics > 1) {
	$code .= '
        $loop_count[0]++;
';
    };
    $code .= '
	while (@all_paths) {
';
    if ($do_visual) {
# XXX vielleicht auch: tags von visual0 bis visualX festlegen
# red_val-Inkrement mit (255-100)/X festlegen
# nachträglich mit itemconfigure ändern
	$code .= '
	    if (Tk::timeofday() > $last_time+$visual_delay) {
                $canvas->idletasks;
                $last_time = Tk::timeofday();
            }
            $red_val+=5 if $red_val < 255;
            my $red_col = sprintf("#%02x0000", $red_val);
';
    }
    if ($sc->Statistics > 2) {
	$code .= '
            $loop_count[1]++;
';
    };
    $code .= '
	    my @new_all_paths;
	    foreach my $path_def (@all_paths) {
';
    if ($sc->Statistics > 3) {
	$code .= '
                $loop_count[2]++;
';
    };
    $code .= '
		my @path = @{$path_def->[0]};
		my $curr_len = $path_def->[1];
';
    if ($sc->HasPenalty) {
	$code .= '
		my $curr_pen = $path_def->[3];
';
	if ($sc->HasAmpeln) {
	    $code .= '
		my $ampeln   = $path_def->[4];
';
	}
    }
    if ($seen_optimierung) {
	$code .= '
                my $seen = $path_def->[5];
';
    }
    $code .= '
		my $last_node = $path[$#path];
';
    if ($use_2) {
	$code .= '
                my $net_s = $net->[$last_node];
                my $net_s_len = length($net_s);
                for(my $i = 0; $i < $net_s_len; $i+=8) {
                    my $next_node = unpack("l", substr($net_s, $i, 4));
                    my $len = unpack("l", substr($net_s, $i+4, 4));
';
    } else {
	$code .= '
	        my $last_node_ref = $net->{$last_node};
		while(my($next_node, $len)
		      = each %$last_node_ref) {
';
    }
    if ($seen_optimierung) {
	$code .= '
                   next if $seen->{$next_node};
';
    }

    $code .= '
                    next if $#path > 0 && $next_node eq $path[$#path-1];
';
    if ($do_visual) {
	$code .= '
                    { my($lx, $ly) = $transpose_sub->(split(/,/, $last_node));
                      my($nx, $ny) = $transpose_sub->(split(/,/, $next_node));
                      $canvas->createLine($lx,$ly,$nx,$ny,
                                          -tag=>"visual",
                                          -fill=>$red_col,-width=>3);
                    }
';
    }
    if ($sc->Statistics) {
	$code .= '
                    $node_touches++;
';
    }
    my $sort_index = ($sc->HasPenalty ? 3 : 1);

    if ($sc->HasPenalty) {
	$code .= '  my $pen = $len;
';
    }
    $code .= $penalty_code;
    $code .= '
		    my $next_node_'.$len_pen." = \$".$len_pen.' + $curr_'.$len_pen . ';
' . $skip_path_code;
    if ($sc->HasAmpeln) {
	# XXX Penalty anpassen, falls nach links/rechts abgebogen wird.
	# Keine Penalty bei Besonderheiten (nur eine Richtung ist relevant,
	# Fußgängerampel...) XXX
	$code .= '
		    if (exists $ampel_net->{$next_node}) {
			$next_node_pen += ' . $sc->AmpelPenalty . ';
' . $skip_path_code . '
			$ampeln++;
		    }
';
    }

    if ($sc->HasAbbiegen) {
	# Dieser Code ist nicht perfekt, aber eine gute Näherung.
	# Es wird festgestellt, ob es im vorherigen Knoten einen
	# Linksabbiegevorgang ohne Ampel gab. Wenn ja, wird noch
	# festgestellt, ob es beim Abbiegen eine Kategorieänderung
	# gab. Nur in diesem Fall ist ein echtes Linksabbiegen
	# wahrscheinlich, ansonsten hat die Straße möglicherweise nur
	# einen leichten Knick gemacht. Da Hauptstraßenkreuzungen
	# üblicherweise eine Ampel haben, geht diese Regel nur bei
	# Kreuzungen von Nebenstraßen und Hauptstraßen.
	# XXX Echte Geradeausstrecken feststellen.
	$code .= '
                    if (@path > 1 and
                        !exists $ampel_net->{$path[$#path]} and
                        $net->{$path[$#path]} > 2
                       ) {
                        if ((Strassen::Util::abbiegen_s($path[$#path-1],
                                                        $path[$#path],
                                                        $next_node))[0] eq "l") {
                            my $str_i0 = $self->net2name($path[$#path-1],
                                                         $path[$#path]);
                            my $str_i = $self->net2name($path[$#path],
                                                        $next_node);
                            my $cat0 = $str->get($str_i0)->[2];
                            my $cat = $str->get($str_i)->[2];
                            if (($category_order->{$cat0} < $category_order->{$cat}
                                 and exists $abbiegen_penalty->{$cat}) or
                                ($category_order->{$cat0} > $category_order->{$cat}
                                 and exists $abbiegen_penalty->{$cat0})) {
#warn "pen=".($abbiegen_penalty->{$cat}||$abbiegen_penalty->{$cat0})." for " . $str->get($self->net2name($path[$#path-1],$path[$#path]))->[0] . " => " . $str->get($str_i)->[0] . "\n";
                                $next_node_pen += $abbiegen_penalty->{$cat};
' . $skip_path_code . '
                            }
			}
                    }
';
    }
    $code .= ($aufschlag_code ne '' ? '
                    if (!exists $visited{$next_node} or
                        $next_node_'.$len_pen.' < $visited{$next_node}) {' 
	      : '') . '
		        $visited{$next_node} = $next_node_'.$len_pen.';
' . ($aufschlag_code ne '' ? '}' : '') . '
';
    if ($sc->HasPenalty) {
	$code .= '
		    my $next_node_len = $len + $curr_len;
';
    }
    $code .= '
		    if ($next_node eq $to) {
			my @koords = (@path, $to);
';
    if ($use_2) {
	$code .= '
	                foreach (@koords) {
                            $_ = join(",", unpack("l2", $self->{Index2Coord}[$_]));
			}
';
    }
    $code .= '
			warn "Found path, len: $next_node_len\n"
			    if $VERBOSE;
			push(@found_paths,
			     [Strassen::to_koord(\@koords),
			      $next_node_len';
    if ($sc->HasPenalty) {
	$code .= ',
			      undef,
			      $next_node_pen,
';
	if ($sc->HasAmpeln) {
	    $code .= '			      $ampeln,
';
	}
    }
    $code .= '			     ]
			    );
';
    if ($pure_depth) {
	$code .= '
                        last BIGLOOP;
';
    }
    $code .= '
			next;
		    }
		    my $virt_'.$len_pen.' = $next_node_'.$len_pen;
    if ($use_2) {
	$code .= '
		      + Strassen::Util::strecke_i($self, $next_node, $to);
';
    } else {
	$code .= '
		      + Strassen::Util::strecke_s($next_node, $to);
';
    }
    if ($seen_optimierung) {
	$code .= '
                      $seen->{$next_node} = 1;
';
    }
    $code .= $skip_path_code2 . '
                    my $new_path_ref = [[@path, $next_node],
					 $next_node_len,
					 $virt_'.$len_pen.',
';
    if ($sc->HasPenalty) {
	$code .= '					  $next_node_pen,';
	if ($sc->HasAmpeln) {
	    $code .= '					  $ampeln,';
	}
    }
    if ($seen_optimierung) {
	$code .= '
                                                          $seen,';
    }
    $code .= '					 ];
                    push @new_all_paths, $new_path_ref;
		}
	    }
';
    if ($sc->Statistics) {
	$code .= '
	    if ($max_new_paths < @all_paths) { $max_new_paths = @all_paths }
';
    }
    if ($pure_depth || $backtracking) {
	$code .= '
	    @all_paths = (sort({ $a->[2] <=> $b->[2] } @new_all_paths),
	                 @suspended_paths);
';
    } else {
	$code .= '
	    @all_paths = sort { $a->[2] <=> $b->[2] } 
	                 (@new_all_paths, @suspended_paths);
';
    }
    $code .= '
	    { local $^W = 0;
            @suspended_paths = splice(@all_paths, ' . $cut_path_nr . ');
	    }
';
    if ($sc->Statistics) {
	$code .= '
	    if ($max_suspended_paths < @suspended_paths) {
                $max_suspended_paths = @suspended_paths;
            }
';
    }
	    # @all_paths enthält jetzt die besten 5 Pfade,
	    # während in @suspended_paths alle anderen sind
	    # Damit wird gesichert, daß
	    # a) die besten Pfade nur bevorzugt bearbeitet werden
	    # b) suspended_paths, falls sie irgendwann mal besser werden,
	    #    doch wieder zum Zug kommen können
    $code .= '

	}
	if (@suspended_paths) {
	    @all_paths = sort { $a->[2] <=> $b->[2] } splice
	      (@suspended_paths, 0, 5);
	} else {
	    last;
	}
    }

    if (!@found_paths) {
	warn "Nothing found!\n" if $VERBOSE;
        ';
    $code .= ($args{All} ? '()' : 'undef');
    $code .= ';
    } else {
	@found_paths = sort { $a->['.$sort_index.'] <=> $b->['.$sort_index.'] } @found_paths;
        ';

    if ($sc->Statistics) {
	$code .= '
        $visited_nodes = scalar keys %visited;
        warn "\nAlgorithm: SRT (CutPath=' . $cut_path_nr .', PureDepth=' . $pure_depth . ', BackTracking=' . $backtracking . ')\n";
';
    }

    $code .= ($args{All} 
	      ? ($args{OnlyPath}
		 ? 'map { $_->[0] } @found_paths'
		 : '@found_paths'
		)
	      : ($args{OnlyPath}
		 ? '$found_paths[0]->[0]'
		 : '$found_paths[0]'
		)
	     );
    $code .= ';
    }
 } # Achtung, Einrückung für make_autoload!
';

    $code;
}

1;

__END__
