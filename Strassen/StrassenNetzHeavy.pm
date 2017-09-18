# -*- perl -*-

#
# Copyright (c) 1995-2003,2012,2017 Slaven Rezic. All rights reserved.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.de
#

package Strassen::StrassenNetzHeavy;

package StrassenNetz;
use Strassen::StrassenNetz;
use strict;
use vars @StrassenNetz::EXPORT_OK;

### AutoLoad Sub
sub new_from_server {
    my $class = shift;
    my $server_name = shift || 'bbb';
    # nachgucken, ob vielleicht str_server.pl läuft

    my $net;

    my $try_sharelite = sub {
	require IPC::ShareLite;
        local $SIG{__DIE__};
	require Storable;
	my %options = (
		       -key => '1211', # XXX get from var
		       -create => 'no',
		       -exclusive => 'no',
		       -destroy => 'no',
		      );
	my $share = IPC::ShareLite->new(%options) or die $!;
	warn "Shared memory anzapfen...\n" if ($VERBOSE);
	$net = Storable::thaw($share->fetch);
	use_data_format($FMT_HASH) if $net;
    };

    my $try_shareable = sub {
	require IPC::Shareable;
	IPC::Shareable->VERSION(0.60); # no more no/yes
	my %options = (
		       'key' => 'paint',
		       'create' => 0,
		       'exclusive' => 0,
		       'mode' => 0644,
		       'destroy' => 0,
		      );
	warn "Shared memory anzapfen...\n" if ($VERBOSE);
	tie $net, 'IPC::Shareable', $server_name, \%options;
	#tie $net->{Net}, 'IPC::Shareable', $server_name."1", \%options;
	#tie $net->{Net2Name}, 'IPC::Shareable', $server_name."2", \%options;
	use_data_format($FMT_HASH) if $net;
    };

    eval { $try_sharelite->() };
    warn $@ if !$net && $VERBOSE;
    return $net if $net;

    eval { $try_shareable->() };
    warn $@ if !$net && $VERBOSE;
    return $net if $net;

    undef;
}

### AutoLoad Sub
sub statistics {
    my $self = shift;
    my $msg = '';
    if ($self->{Strassen}) {
	$msg .= "Anzahl der Straßen:    " . $self->{Strassen}->count . "\n";
    }

    if ($self->{Net2Name}) {
	my $count = 0;
	while(my($k,$v) = each %{$self->{Net2Name}}) {
	    $count += scalar keys %$v;
	}
	$msg .= "Anzahl der Kanten:     " . $count . "\n";

	my $nodes = scalar keys %{$self->{Net2Name}};
	$msg .= "Anzahl der Knoten:     " . $nodes . "\n";

	if ($nodes) {
	    $msg .= "node branching factor: " .
		sprintf("%.1f", $count/$nodes) . "\n";
	}
    }

    $msg .= "Sourcen: " . join(", ", $self->sourcefiles) . "\n";
    $msg .= "Abhängige Dateien: " . join(", ", $self->dependent_files) . "\n";
    $msg .= "Id: " . $self->id . "\n";

    $msg;
}

# Erzeugt ein Netz, deren Kanten nur von Kreuzung zu Kreuzung gehen.
# Dieses Netz wird als StrassenNetz-Objekt in WideNet abgelegt.
# Zusätzlich enthält es eine Struktur WideNeighbors, dass für Nicht-Kreuzungs-
# Knoten die nächsten Kreuzungs-Knoten anzeigt:
#    Node => [Neighbor1, Distance1, Neighbor2, Distance2]
### AutoLoad Sub
sub make_wide_net {
    my $orig_net_obj = shift;
    my $orig_net     = $orig_net_obj->{Net};

    my $new_net_obj          = StrassenNetz->new($orig_net_obj->{Strassen});
    $orig_net_obj->{WideNet} = $new_net_obj;
    my $new_net              = $new_net_obj->{Net} = {};
    my $wide_neighbors       = $new_net_obj->{WideNeighbors} = {};
    my $intermediates_hash   = $new_net_obj->{Intermediates} = {};

#XXX was ist, wenn $new_new->{$node}{$last_node} schon existiert? =>
# Distanzvergleich machen!
# Attributänderungen beachten!
    while(my($node,$neighbors) = each %{ $orig_net }) {
	next if keys %$neighbors == 2;
	for my $neighbor (keys %$neighbors) {
	    my(%seen_node) = ($node => 1,
			      $neighbor => 1);
	    my $last_node = $neighbor;
	    my $distance  = Strassen::Util::strecke_s($node, $last_node);
	    my @intermediates;
	    while (1) {
		my @neighbor_neighbors = keys %{ $orig_net->{$last_node} };
		if (scalar @neighbor_neighbors != 2) {
		    # end node or crossing node
		    # int is sufficient, as we are dealing with meters
# XXX $node == $last_node?
if ($node eq $last_node) {warn "$node == $last_node\n";}
		    $new_net->{$node}{$last_node} = int($distance);
                    if (@intermediates) {
			$intermediates_hash->{$node}{$last_node} =
			    [ map { $_->[0] } @intermediates ];
			foreach my $intermediate_def (@intermediates) {
			    my($intermediate, $node_dist) = @$intermediate_def;
			    $wide_neighbors->{$intermediate} =
				[$node      => $node_dist,
				 $last_node => int($distance)-$node_dist];
			}
		    }
		    last;
		} else {
		    push @intermediates, [$last_node, int($distance)];
		    my $next_node = $neighbor_neighbors[0];
		    if ($seen_node{$next_node}) {
			$next_node = $neighbor_neighbors[1];
			if ($seen_node{$next_node}) {
			    die "Should not happen: $next_node already seen";
			}
		    }
		    $seen_node{$next_node}++;
		    $distance += Strassen::Util::strecke_s($last_node,
							   $next_node);
		    $last_node = $next_node;
		}
	    }
	}
    }
}

# Create net with the category as value (instead of distance between nodes).
# If -obeydir is true, then make a distinction between both directions.
# If -net2name is true, then create Net2Name member.
# If -multiple is true, then allow multiple values per street connection.
#   In this case values are always array references.
# Turn caching on/off with -usecache. If -usecache is not specified, the
#   global value from $Strassen::Util::cacheable is used.
# If -onewayhack is true, then handle some directed categories (1, 1s, 3)
# specifically.
### AutoLoad Sub
sub make_net_cat {
    my($self, %args) = @_;
    my $obey_dir    = $args{-obeydir} || 0;
    my $do_net2name = $args{-net2name} || 0;
    my $multiple    = $args{-multiple} || 0;
    my $onewayhack  = $args{-onewayhack} || 0;
    my $cacheable   = defined $args{-usecache} ? $args{-usecache} : $Strassen::Util::cacheable;
    my $args2filename = join("_", $obey_dir, $do_net2name, $multiple);

    my $cachefile;
    if ($cacheable) {
	#XXXmy @src = $self->sourcefiles;
	my @src = $self->dependent_files;
	if (!@src || grep { !defined $_ } @src) {
	    warn "Not cacheable..." if $VERBOSE;
	    $cacheable = 0;
	} else {
	    $cachefile = $self->get_cachefile;
	    my $net2name = Strassen::Util::get_from_cache("net2name_" . $args2filename . "_$cachefile", \@src);
	    my $net = Strassen::Util::get_from_cache("net_" . $args2filename . "_$cachefile", \@src);
	    if (defined $net2name && defined $net) {
		$self->{Net2Name} = $net2name;
		$self->{Net} = $net;
		warn "Using cache for $cachefile\n" if $VERBOSE;
		return;
	    }
	}
    }
    $self->{Net} = {};
    $self->{Net2Name} = {};
    my $net      = $self->{Net};
    my $net2name = $self->{Net2Name};
    my $strassen = $self->{Strassen};
    $strassen->init;
    local $^W = 0;
    while(1) {
	my $ret = $strassen->next;
	my @kreuzungen = @{$ret->[Strassen::COORDS()]};
	last if @kreuzungen == 0;
	my($cat_hin, $cat_rueck);
	# seperate forw/back direction and strip addinfo part (new/old style)
	if ($ret->[Strassen::CAT()] =~ /^(.*?)(?:::?.*)?;(.*?)(?:::?.*)?$/) {
	    ($cat_hin, $cat_rueck) = ($1, $2);
	} else {
	    ($cat_hin) = ($cat_rueck) = $ret->[Strassen::CAT()] =~ /^(.*?)(?:::?.*)?$/;
	    if ($onewayhack && $cat_hin =~ m{^(1|1s|3)$}) { # this are the directed categories
		$cat_rueck = "";
	    }
	}
	my $strassen_pos = $strassen->pos;
	my $i;
	for($i = 0; $i < $#kreuzungen; $i++) {
	    if ($cat_hin ne "") {
		if ($multiple) {
		    push @{$net->{$kreuzungen[$i]}{$kreuzungen[$i+1]}}, $cat_hin;
		} else {
		    $net->{$kreuzungen[$i]}{$kreuzungen[$i+1]} = $cat_hin;
		}
	    }
	    if (!$obey_dir && $cat_rueck ne "") {
		if ($multiple) {
		    push @{$net->{$kreuzungen[$i+1]}{$kreuzungen[$i]}}, $cat_rueck;
		} else {
		    $net->{$kreuzungen[$i+1]}{$kreuzungen[$i]} = $cat_rueck;
		}
	    }
	    if ($do_net2name) {
		if ($cat_hin ne "") {
		    if ($multiple) {
			push @{$net2name->{$kreuzungen[$i]}{$kreuzungen[$i+1]}}, $strassen_pos;
		    } else {
			$net2name->{$kreuzungen[$i]}{$kreuzungen[$i+1]} = $strassen_pos;
		    }
		}
		if (!$obey_dir && $cat_rueck ne "") {
		    if ($multiple) {
			push @{$net2name->{$kreuzungen[$i+1]}{$kreuzungen[$i]}}, $strassen_pos;
		    } else {
			$net2name->{$kreuzungen[$i+1]}{$kreuzungen[$i]} = $strassen_pos;
		    }
		}
	    }
	}
    }

    if ($cacheable) {
	Strassen::Util::write_cache($net2name, "net2name_" . $args2filename . "_$cachefile", -modifiable => 1);
	Strassen::Util::write_cache($net, "net_" . $args2filename . "_$cachefile", -modifiable => 1);
	if ($VERBOSE) {
	    warn "Wrote cache ($cachefile)\n";
	}
    }

}

# Create a special cycle path/street category net
# Categories created are:
#    H    => H, B or HH without cycle path and bus lane
#    H_RW => same with cycle path
#    H_BL => same with bus lane
#    N    => NH, N or NN without cycle path and bus lane
#    N_RW => same with cycle path
#    N_BL => same with bus lane
# %args: may be UseCache => $boolean
# Note: former versions of this function had a "$type" argument in
#       between, which is not needed and is now removed.
### AutoLoad Sub
sub make_net_cyclepath {
    my($self, $cyclepath, %args) = @_;

    my $cachefile;
    my $cacheable = defined $args{UseCache} ? $args{UseCache} : $Strassen::Util::cacheable;
    if ($cacheable) {
	#XXXmy @src = $self->sourcefiles;
	my @src = $self->dependent_files;
	push @src, $cyclepath->dependent_files;
	$cachefile = $self->get_cachefile;
	my $net = Strassen::Util::get_from_cache("net_cyclepath_$cachefile", \@src);
	if (defined $net) {
	    $self->{Net} = $net;
	    if ($VERBOSE) {
		warn "Using cache for $cachefile\n";
	    }
	    return;
	}
    }

    $self->{Net} = {};
    my $net      = $self->{Net};
    my $strassen = $self->{Strassen};

    my $cyclepath_net = __PACKAGE__->new($cyclepath);
    $cyclepath_net->make_net_cat(-obeydir => 1);
    my $c_net = $cyclepath_net->{Net};

    # net2name ist (noch) nicht notwendig
    $strassen->init;
    while(1) {
	my $ret = $strassen->next;
	my @kreuzungen = @{$ret->[Strassen::COORDS()]};
	last if @kreuzungen == 0;
	my $cat = $ret->[Strassen::CAT()];
	for my $i (0 .. $#kreuzungen-1) {
	    my $str_cat   = ($cat =~ /^(H|HH|B)$/ ? 'H' : 'N');
	    if (exists $c_net->{$kreuzungen[$i]}{$kreuzungen[$i+1]}) {
		if ($c_net->{$kreuzungen[$i]}{$kreuzungen[$i+1]} eq 'RW5') {
		    $net->{$kreuzungen[$i]}{$kreuzungen[$i+1]} = $str_cat."_Bus";
		} else {
		    $net->{$kreuzungen[$i]}{$kreuzungen[$i+1]} = $str_cat."_RW";
		}
	    } else {
		$net->{$kreuzungen[$i]}{$kreuzungen[$i+1]} = $str_cat;
	    }
	    if (exists $c_net->{$kreuzungen[$i+1]}{$kreuzungen[$i]}) {
		if ($c_net->{$kreuzungen[$i+1]}{$kreuzungen[$i]} eq 'RW5') {
		    $net->{$kreuzungen[$i+1]}{$kreuzungen[$i]} = $str_cat."_Bus";
		} else {
		    $net->{$kreuzungen[$i+1]}{$kreuzungen[$i]} = $str_cat."_RW";
		}
	    } else {
		$net->{$kreuzungen[$i+1]}{$kreuzungen[$i]} = $str_cat;
	    }
	}
    }

    if ($cacheable) {
	Strassen::Util::write_cache($net, "net_cyclepath_$cachefile", -modifiable => 1);
	if ($VERBOSE) {
	    warn "Wrote cache ($cachefile)\n";
	}
    }

}

# Create a data structure (a hash ref) for the DirectedHandicap search feature.
# Parameters:
# - Strassen object
# - %args:
#   - speed: speed in km/h, required for converting time penalties
# 
### AutoLoad Sub
sub make_net_directedhandicap {
    my($self, $s, %args) = @_;
    my $speed_kmh = delete $args{speed};
    my $vehicle = delete $args{vehicle} || '';
    $vehicle = '' if $vehicle eq 'normal'; # alias
    my %time;
    $time{kerb_up}   = delete $args{kerb_up_time};
    $time{kerb_down} = delete $args{kerb_down_time};
    die "Unhandled options: " . join(" ", %args) if %args;
    my $speed_ms = $speed_kmh / 3.6;
    # XXX check kerb times!
    if (!defined $time{kerb_up}) {
	$time{kerb_up} =
	    {''          => 4,
	     'childseat' => 5,
	     'trailer'   => 12,
	     'cargobike' => 18,
	     'heavybike' => 40,
	    }->{$vehicle};
    }
    if (!defined $time{kerb_down}) {
	$time{kerb_down} =
	    {''          => 2,
	     'childseat' => 3,
	     'trailer'   => 8,
	     'cargobike' => 13,
	     'heavybike' => 25,
	    }->{$vehicle};
    }

    my %directed_handicaps;
    my $warned_too_few_coord;
    my $warned_invalid_cat;
    $s->init;
    while() {
	my $r = $s->next;
	my @c = @{ $r->[Strassen::COORDS()] };
	last if !@c;
	if (@c < 3) {
	    if (!$warned_too_few_coord++) {
		warn "Invalid directedhandicap record: less than three coordinates. Entry is: @$r (warn only once)";
	    }
	}
	my $pen;
	my $len;
	if ($r->[Strassen::CAT()] =~ m{^DH:(.+)$}) {
	    my $attrs = $1;
	    for my $attr (split /:/, $attrs) {
		if ($attr =~ m{^t=(\d+)$}) {
		    my $time = $1;
		    $pen += $time * $speed_ms;
		} elsif ($attr =~ m{^len=(\d+)$}) {
		    $pen += $1;
		    $len += $1;
		} elsif ($attr =~ m{^kerb_(?:up|down)$}) {
		    $pen += $time{$attr} * $speed_ms;
		} else {
		    if (!$warned_invalid_cat++) {
			warn "Invalid attr '$attr'. Entry is @$r (warn only once)";
		    }
		}
	    }
	} else {
	    if (!$warned_invalid_cat++) {
		warn "Invalid category '$r->[Strassen::CAT()]'. Entry is @$r (warn only once)";
	    }
	}
	if (defined $pen) {
	    my $last = pop @c;
	    push @{ $directed_handicaps{$last} }, { p => \@c, pen => $pen, len => $len };
	}
    }
    return {
	    Net     => \%directed_handicaps,
	    SpeedMS => $speed_ms,
	   };
}

sub directedhandicap_get_losses {
    my(undef, $directed_handicap_net, $route_path_ref) = @_;
    my $net = $directed_handicap_net->{Net};
    my $speed_ms = $directed_handicap_net->{SpeedMS};
    my @route_path = map { join ',', @$_ } @$route_path_ref;
    my @ret;
    for(my $rp_i=1; $rp_i<=$#route_path; $rp_i++) {
	my $next_node = $route_path[$rp_i];
	if (exists $net->{$next_node}) {
	    my $directed_handicaps = $net->{$next_node};
	FIND_MATCHING_DIRECTED_HANDICAPS: {
		for my $directed_handicap (@$directed_handicaps) {
		    my $rp_j = $rp_i-1;
		    my $this_node = $route_path[$rp_j];
		    my $handicap_path = $directed_handicap->{p};
		FIND_MATCHING_DIRECTED_HANDICAP: {
			for(my $hp_i=$#$handicap_path; $hp_i>=0; $hp_i--) {
			    if ($handicap_path->[$hp_i] ne $this_node) {
				last FIND_MATCHING_DIRECTED_HANDICAP;
			    }
			    if ($hp_i > 0) {
				last FIND_MATCHING_DIRECTED_HANDICAP
				    if $rp_j == 0;
				$this_node = $route_path[--$rp_j];
			    }
			}
			push @ret,
			    {
			     path_begin_i => $rp_j,
			     path_end_i   => $rp_i,
			     add_len      => $directed_handicap->{len},
			     lost_time    => $directed_handicap->{pen} / $speed_ms,
			    };
			last FIND_MATCHING_DIRECTED_HANDICAPS;
		    }
		}
	    }
	}
    }
    @ret;
}

# XXX Abspeichern der Wegfuehrung nicht getestet
### AutoLoad Sub
sub save_net_mldbm {
    my($self, $dir) = @_;
    if (!keys %{$self->{Net}}) {
	die "Net is empty";
    }
    require MLDBM;
    MLDBM->import('DB_File', $MLDBM_SERIALIZER);
    require Fcntl;
    require File::Basename;

    # XXX use dependent_files?
    my(@src) = $self->sourcefiles;
    $dir = $Strassen::Util::cachedir unless $dir;
    my $file_net = "$dir/net_" .
	join("_", map { File::Basename::basename($_) } @src);
    my $file_net2name = "$dir/net2name_" .
	join("_", map { File::Basename::basename($_) } @src);
    my $file_wegfuehrung = "$dir/wegfuehrung_" .
	join("_", map { File::Basename::basename($_) } @src);

    my %mldbm_net;
    tie %mldbm_net, 'MLDBM', $file_net, &Fcntl::O_CREAT|&Fcntl::O_RDWR, 0640
      or die $!;
    while(my($k,$v) = each %{$self->{Net}}) {
	$mldbm_net{$k} = $v;
    }
    untie %mldbm_net;

    my %mldbm_net2name;
    tie
      %mldbm_net2name, 'MLDBM', $file_net2name,
      &Fcntl::O_CREAT|&Fcntl::O_RDWR, 0640
	or die $!;
    while(my($k,$v) = each %{$self->{Net2Name}}) {
	$mldbm_net2name{$k} = $v;
    }
    untie %mldbm_net2name;

    my %mldbm_wegfuehrung;
    tie
      %mldbm_wegfuehrung, 'MLDBM', $file_wegfuehrung,
      &Fcntl::O_CREAT|&Fcntl::O_RDWR, 0640
	or die $!;
    while(my($k,$v) = each %{$self->{Wegfuehrung}}) {
	$mldbm_wegfuehrung{$k} = $v;
    }
    untie %mldbm_wegfuehrung;
}

# Ein ernstes Problem ergibt sich bei der Verwendung von MLDBM:
# Da add_net neue Punkte zum Straßennetz hinzufügt, wird der "Schrott"
# dadurch immer größer. Von Zeit zu Zeit sollte also mit make_net und
# save_net_mldbm ein neues, frisches Straßennetz erzeugt werden.
### AutoLoad Sub
sub load_net_mldbm {
    my($self, $dir) = @_;
    require MLDBM;
    MLDBM->import('DB_File', $MLDBM_SERIALIZER);
    require Fcntl;
    require File::Basename;

    # XXX use dependent_files?
    my(@src) = $self->sourcefiles;
    $dir = $Strassen::Util::cachedir unless $dir;
    my $file_net = "$dir/net_" .
	join("_", map { File::Basename::basename($_) } @src);
    my $file_net2name = "$dir/net2name_" .
	join("_", map { File::Basename::basename($_) } @src);
    my $file_wegfuehrung = "$dir/wegfuehrung_" .
	join("_", map { File::Basename::basename($_) } @src);

    my %mldbm_net;
    tie %mldbm_net, 'MLDBM', $file_net, &Fcntl::O_RDWR, 0640
      or die "Can't open $file_net: $!";
    $self->{Net} = \%mldbm_net;

    my %mldbm_net2name;
    tie
      %mldbm_net2name, 'MLDBM', $file_net2name, &Fcntl::O_RDWR, 0640
	or die "Can't open $file_net2name: $!";
    $self->{Net2Name} = \%mldbm_net2name;

    my %mldbm_wegfuehrung;
    tie
      %mldbm_wegfuehrung, 'MLDBM', $file_wegfuehrung, &Fcntl::O_RDWR, 0640
	or die "Can't open $file_wegfuehrung: $!";
    $self->{Wegfuehrung} = \%mldbm_wegfuehrung;

    $self->{UseMLDBM} = 1;
}

### AutoLoad Sub
sub wide_search {
    my($self, $search_sub, $self2, $from, $to) = @_;

    if (!$self->{WideNet}) {
	warn "Make wide net...\n";
	$self->make_wide_net;
    }

    my $wide_net = $self->{WideNet}{Net};
    for my $node ($from, $to) {
	if (!exists $wide_net->{$node}) {
	    my $neighbor_def = $self->{WideNet}{WideNeighbors}{$node};
	    if (!defined $neighbor_def) {
		die "Can't find neighbors for node $node";
	    }
	    # XXX rückwärts??? (Einbahnstraßen)
	    $wide_net->{$node}{$neighbor_def->[WIDE_NEIGHBOR1]} = $neighbor_def->[WIDE_DISTANCE1];
	    $wide_net->{$node}{$neighbor_def->[WIDE_NEIGHBOR2]} = $neighbor_def->[WIDE_DISTANCE2];
	    $wide_net->{$neighbor_def->[WIDE_NEIGHBOR1]}{$node} = $neighbor_def->[WIDE_DISTANCE1];
	    $wide_net->{$neighbor_def->[WIDE_NEIGHBOR2]}{$node} = $neighbor_def->[WIDE_DISTANCE2];
	}
    }

    $search_sub->($self->{WideNet}, $from, $to);
}

# Expandiert das Ergebnis einer Suche in WideNet
### AutoLoad Sub
sub expand_wide_path {
    my($self, $pathref) = @_;
    return [] if (@$pathref == 0); # keep it empty

    my @new_path;
    my $net     = $self->{Net};
    my $widenet = $self->{WideNet}->{Net};
    my $intermediates_hash = $self->{WideNet}->{Intermediates};
    for(my $i = 0; $i<$#$pathref; $i++) {
	my $from = join(",",@{$pathref->[$i]});
	my $to   = join(",",@{$pathref->[$i+1]});
	push @new_path, $pathref->[$i];
	if (!exists $net->{$from}{$to}) {
	    my @intermediates;
	    if (exists $intermediates_hash->{$from}{$to}) {
		@intermediates = @{ $intermediates_hash->{$from}{$to} };
	    } elsif (exists $intermediates_hash->{$to}{$from}) {
		warn "Fallback to reverse intermediates $to => $from";
		@intermediates = @{ $intermediates_hash->{$to}{$from} };
	    } else {
		warn "Can't find intermediates between $from and $to";
		next;
	    }
	    foreach my $node (@intermediates) {
		push @new_path, [split /,/, $node];
	    }
	}
    }
    push @new_path, $pathref->[-1];
    \@new_path;
}

# Bei einer Speicherung als MLDBM muß der in der Manpage beschriebene
# Bug umgangen werden. Diese Funktion funktioniert für
# zweistufige Hashes
sub store_to_hash {
    my($self, $mldbm_hash, $key1, $key2, $val) = @_;
    if ($self->{UseMLDBM}) {
	my $tmp = $mldbm_hash->{$key1};
	$tmp->{$key2} = $val;
	$mldbm_hash->{$key1} = $tmp;
    } else {
	$mldbm_hash->{$key1}{$key2} = $val;
    }
}

### AutoLoad Sub
sub add_faehre {
    my($self, $faehre_file, %args) = @_;
    require Strassen::Core;
    my $faehre_obj = new Strassen $faehre_file;
    $faehre_obj->init;
    while(1) {
	my $ret = $faehre_obj->next;
	last if !@{$ret->[Strassen::COORDS()]};
	my @kreuzungen = @{$ret->[Strassen::COORDS()]};
	my $i;
	# XXX record to make deletion possible
	for($i = 1; $i<=$#kreuzungen; $i++) {
	    $self->{Net}{$kreuzungen[$i-1]}{$kreuzungen[$i]} = 0;
	    $self->{Net}{$kreuzungen[$i]}{$kreuzungen[$i-1]} = 0;
	    $self->{Net2Name}{$kreuzungen[$i-1]}{$kreuzungen[$i]} =
	      "Fähre " . $ret->[Strassen::NAME()];
	}
    }
}

# Self:
# (Multi)Strassen-Objekt der Linien
# Argument:
# (Multi)Strassen-Objekt der Bahnhöfe
# optional: -addmap     (Mapping der Umsteigebahnhöfe)
#           -addmapfile (Datei mit Mapping)
#	    -cb         (Callback which will be called for each added line.
#		         Callback args are: $self, $coords1, $coords2, $entf,
#			 		    $name_of_link_point
#                        The callback is called only once (should be repeated
#                        for both directions) and also for zero-length
#			 change situations.)
### AutoLoad Sub
sub add_umsteigebahnhoefe {
    my($self, $bhf_obj, %args) = @_;

    my $cb = delete $args{-cb};

    if (exists $args{-addmapfile}) {
    TRY: {
	    foreach my $dir (@Strassen::datadirs) {
		if (open(F, "$dir/" . $args{-addmapfile})) {
		    my %map;
		    while(<F>) {
			next if /^\#/;
			chomp;
			my(@l) = split /\t/;
			$map{$l[0]} = $l[1];
		    }
		    close F;
		    if (keys %map) {
			$args{-addmap} = \%map;
		    }
		    last TRY;
		}
	    }
	}
    }

    my %bahnhoefe;
    $bhf_obj->init;
    while(1) {
	my $ret = $bhf_obj->next;
	last if !@{ $ret->[Strassen::COORDS()] };
	my $name   = Strassen::strip_bezirk($ret->[Strassen::NAME()]);
	if (defined $args{-addmap} and
	    exists $args{-addmap}->{$name}) {
	    $name = $args{-addmap}->{$name};
	}
	my $coords = $ret->[Strassen::COORDS()][0];
	if (exists $bahnhoefe{$name}) {
	    foreach my $p (@{ $bahnhoefe{$name} }) {
		my $entf = 0;
		if ($coords ne $p) {
		    $entf = Strassen::Util::strecke_s($coords, $p);
		    $self->store_to_hash($self->{Net}, $coords, $p, $entf);
		    $self->store_to_hash($self->{Net}, $p, $coords, $entf);
		}
		if ($cb) { $cb->($self, $coords, $p, $entf, $name) }
	    }
	    push @{ $bahnhoefe{$name} }, $coords;
	} else {
	    $bahnhoefe{$name} = [$coords];
	}
    }
}

######################################################################
# User deletions

### AutoLoad Sub
sub toggle_deleted_line {
    my($net, $xy1, $xy2, $on_callback, $off_callback, $del_token) = @_;
    $del_token ||= "";
    my $deleted_net = ($net->{"_Deleted"}{$del_token} ||= {});
    if (exists $deleted_net->{$xy1}{$xy2} ||
	exists $deleted_net->{$xy2}{$xy1}) {
	$net->remove_from_deleted($xy1,$xy2,$off_callback,$del_token);
    } else {
	$net->add_to_deleted($xy1,$xy2,$on_callback,$del_token);
    }
}

### AutoLoad Sub
sub remove_from_deleted {
    my($net, $xy1, $xy2, $off_callback, $del_token) = @_;
    $del_token ||= "";
    my $deleted_net = ($net->{"_Deleted"}{$del_token} ||= {});
    $net->{Net}{$xy1}{$xy2} = $deleted_net->{$xy1}{$xy2}
	if exists $deleted_net->{$xy1}{$xy2};
    delete $deleted_net->{$xy1}{$xy2};
    $net->{Net}{$xy2}{$xy1} = $deleted_net->{$xy2}{$xy1}
	if exists $deleted_net->{$xy2}{$xy1};
    delete $deleted_net->{$xy2}{$xy1};
    $off_callback->($xy1, $xy2, $del_token) if ($off_callback);
}

### AutoLoad Sub
sub remove_all_from_deleted {
    my($net, $off_callback, $del_token) = @_;
    my $deleted_net = ($net->{"_Deleted"} ||= {});
    my $added_wegfuehrung = ($net->{"_Added_Wegfuehrung"} ||= {});
    my @del_tokens;
    if (defined $del_token) {
	@del_tokens = $del_token;
    } else {
	@del_tokens = keys %{ $deleted_net };
    }

    for my $del_token (@del_tokens) {
	while(my($xy1,$v1) = each %{ $deleted_net->{$del_token}}) {
	    while(my($xy2,$v2) = each %$v1) {
		$net->remove_from_deleted($xy1,$xy2,$off_callback,$del_token);
	    }
	}
	while(my($coord,$coords) = each %{ $added_wegfuehrung->{$del_token} }) {
	    # XXX should also be a separate method, like remove_from_deleted?
	    # XXX $off_callback handling is missing!
	    my @changed_wegf;
	    for my $wegf (@{ $net->{Wegfuehrung}{$coord} || [] }) {
		if (!$coords->{join(" ", @$wegf)}) {
		    push @changed_wegf, $wegf;
		}
	    }
	    if (@changed_wegf) {
		$net->{Wegfuehrung}{$coord} = \@changed_wegf;
	    } else {
		delete $net->{Wegfuehrung}{$coord};
	    }
	}
    }
}

### AutoLoad Sub
sub add_to_deleted {
    my($net, $xy1, $xy2, $on_callback, $del_token) = @_;
    $del_token = "" if !defined $del_token;
    $net->del_net($xy1, $xy2, BLOCKED_COMPLETE(), $del_token);
    $on_callback->($xy1, $xy2, $del_token) if $on_callback;
}

#XXX rewrite to use make_sperre instead of calls to add_to_deleted.
# steps:
# * delete all old {_Deleted}{$del_token} entries (with $off_callback)
# * call make_sperre with the given file/strassen object
# * collect all points {_Deleted}{$del_token}  and call $on_callback on them
# * $on_callback should handle all blocking types
#XXX
# parameters: $filename or $strassen object
#             -merge
#             -oncallback
#             -offcallback
### AutoLoad Sub
sub load_user_deletions {
    my($net, $filename, %args) = @_;
    my $do_merge     = $args{-merge} || 0;
    my $on_callback  = $args{-oncallback};
    my $off_callback = $args{-offcallback};
    my $del_token    = $args{-deltoken} || "";
    my $s = UNIVERSAL::isa($filename, 'Strassen')
	    ? $filename : Strassen->new($filename);
    $s->init;
    my %set;
    while(1) {
	my $ret = $s->next;
	last if @{ $ret->[Strassen::COORDS()] } == 0;
	for(my $inx=0; $inx<$#{$ret->[Strassen::COORDS()]}; $inx++) {
	    $net->add_to_deleted($ret->[Strassen::COORDS()]->[$inx],
				 $ret->[Strassen::COORDS()]->[$inx+1],
				 $on_callback,
				 $del_token);
	    $set{$ret->[Strassen::COORDS()]->[$inx]}->{$ret->[Strassen::COORDS()]->[$inx+1]}++;
	}
    }
    if (!$do_merge) {
	my $deleted_net = ($net->{_Deleted}{$del_token} ||= {});
	while(my($k1,$v1) = each %{ $deleted_net }) {
	    while(my($k2,$v2) = each %$v1) {
		if (!exists $set{$k1}->{$k2} &&
		    !exists $set{$k2}->{$k1}) {
		    $net->remove_from_deleted($k1,$k2, $off_callback,
					      $del_token);
		}
	    }
	}
    }
}

# Args:
# -del_token?
# -type: handicap or oneway or gesperrt (check!)
# -addinfo: add addinfo bit to category
### AutoLoad Sub
sub create_user_deletions_object {
    my $net = shift;
    my(%args) = @_;
    my $del_token = $args{-del_token};
    my $cat = BLOCKED_COMPLETE;
    if (defined $args{-type}) {
	if ($args{-type} eq 'handicap-q4') {
	    $cat = "q4";
	} elsif ($args{-type} eq 'handicap-q4-oneway') {
	    $cat = "q4"; # direction correction follows below
	} elsif ($args{-type} eq 'oneway') {
	    $cat = "1"; # XXX but what about the direction?
	}
    }
    if (defined $args{-addinfo}) {
	$cat .= "::" . $args{-addinfo}; # XXX maybe this will change some day to ":"
    }
    if (defined $args{-type} && $args{-type} eq 'handicap-q4-oneway') {
	$cat .= ";"; # direction correction 
    }

    my $s = Strassen->new;
    my %set;
    my $deleted_net = ($net->{_Deleted}{$del_token} ||= {});
    while(my($k1,$v1) = each %{ $deleted_net }) {
	while(my($k2,$v2) = each %$v1) {
	    if (!exists $set{$k1}->{$k2} &&
		!exists $set{$k2}->{$k1}) {
		$s->push(["userdel", [$k1,$k2], $cat]);
		$set{$k1}->{$k2}++;
	    }
	}
    }

    require Strassen::Combine;
    my $s_combined = $s->make_long_streets;

    $s_combined;
}

### AutoLoad Sub
sub save_user_deletions {
    my($net, $filename, %args) = @_;
    $args{-del_token} ||= "";
    my $s = $net->create_user_deletions_object(%args);
    $s->write($filename);
}

######################################################################
# Zeichnet das Straßennetz, z.B. zum Debuggen.
### AutoLoad Sub
sub draw {
    my($self, $canvas, $transpose_sub) = @_;
    $canvas->delete("netz");
    while(my($node,$neighbors) = each %{ $self->{Net} }) {
	for my $neighbor (keys %$neighbors) {
	    $canvas->createLine($transpose_sub->(split /,/, $node),
  				$transpose_sub->(split /,/, $neighbor),
  				-tags => 'netz',
  				-fill => 'pink',
				-arrow => 'last',
  			       );
	}
    }
}

# Erzeugt ein alternatives Hash für unerlaubte Wegführungen.
# Die einzelnen Paare sehen wie folgt aus (p sind "x,y"-Koordinaten):
# "p0-p1" => ["p2_1", "p2_2" ...]
### AutoLoad Sub
sub alternative_wegfuehrung_net {
    my($net, %args) = @_;
    if ($net->{Alternative_Wegfuehrung} && !$args{-force}) {
	return $net->{Alternative_Wegfuehrung};
    }
    my $alt = {};
    while(my($k,$v) = each %{$net->{Wegfuehrung}}) {
	my(@p) = @$v;
	my $alt_key = "$p[0]-$p[1]";
	if (!exists $alt->{$alt_key}) {
	    $alt->{$alt_key} = [$p[2]];
	} else {
	    push @{ $alt->{$alt_key} }, $p[2];
	}
    }
    $net->{Alternative_Wegfuehrung} = $alt;
    $alt;
}

# Merge $strassen (Strassen or Multistrassen object) to existing net in $net
# XXX Very simple version, does not recognize make_net_cat arguments.
# Also does not do cat =~ /.*;.*/.
sub merge_net_cat {
    my($self, $s, %args) = @_;
    my $net = $self->{Net};
    $s->init;
    while(1) {
	my $ret = $s->next;
	my $c = $ret->[Strassen::COORDS()];
	last if @$c == 0;
	my($cat_hin, $cat_rueck);
	if ($ret->[Strassen::CAT()] =~ /^(.*?)(?:::.*)?;(.*?)(?:::.*)?$/) {
	    ($cat_hin, $cat_rueck) = ($1, $2);
	} else {
	    ($cat_hin) = ($cat_rueck) = $ret->[Strassen::CAT()] =~ /^(.*?)(?:::.*)?$/;
	}
	for my $i (1 .. $#$c) {
	    my($c1,$c2) = ($c->[$i-1], $c->[$i]);
	    $net->{$c1}{$c2} = $cat_hin   if $cat_hin   ne "";
	    $net->{$c2}{$c1} = $cat_rueck if $cat_rueck ne "";
	}
    }
}

# Merge a net from another StrassenNetz object to $self.
sub merge {
    my($self, $another_self, %args) = @_;
    my $overwrite   = $args{-overwrite};
    my $net         = $self->{Net};
    my $another_net = $another_self->{Net};
    while(my($k1,$v1) = each %{ $another_net }) {
	while(my($k2,$v2) = each %$v1) {
	    if (!exists $net->{$k1}{$k2} || $overwrite) {
		$net->{$k1}{$k2} = $v2;
	    }
	}
    }
}

sub push_stack {
    my($self, $another_self) = @_;

    my @modified;
    my @added;

    my $net         = $self->{Net};
    my $another_net = $another_self->{Net};
    while(my($k1,$v1) = each %{ $another_net }) {
	while(my($k2,$v2) = each %$v1) {
	    if (exists $net->{$k1}{$k2}) {
		push @modified, [$k1, $k2, $net->{$k1}{$k2}];
	    } else {
		push @added,    [$k1, $k2];
	    }
	    $net->{$k1}{$k2} = $v2;
	}
    }

    push @{ $self->{_Stack} }, {
				modified => \@modified,
				added    => \@added,
			       };
}

sub pop_stack {
    my($self) = @_;
    my $remember = pop @{ $self->{_Stack} };
    die "Nothing to pop off the stack" if !$remember;
    my $net = $self->{Net};
    for my $modified_entry (@{ $remember->{modified} }) {
	my($k1,$k2,$v) = @$modified_entry;
	$net->{$k1}{$k2} = $v;
    }
    for my $added_entry (@{ $remember->{added} }) {
	my($k1,$k2) = @$added_entry;
	delete $net->{$k1}{$k2};
    }
}

# For debugging only
sub dump_search_nodes {
    my($self, $nodes) = @_;
    while(my($coord, $def) = each %$nodes) {
	printf STDERR "f=%d g=%d\tX; %s %s\n",
	    $def->[StrassenNetz::DIST()], $def->[StrassenNetz::HEURISTIC_DIST()], $def->[StrassenNetz::PREDECESSOR()], $coord;
    }
}

# $route_with_name is the result of route_to_name
# XXX should I check ImportantAngle?
sub compact_route {
    my($self, $route_with_name, %args) = @_;
    my $route_straight_angle = delete $args{-routestraightangle};
    if (!defined $route_straight_angle) {
	$route_straight_angle = 30;
    }
    die "Unknown arguments: " . join(" ", %args) if keys %args;
    return if !@$route_with_name;
    require Storable;
    my @res = Storable::dclone($route_with_name->[0]);
    for my $i (1 .. $#$route_with_name) {
	my $this = $route_with_name->[$i];
	my $last = $res[-1];
	if (!defined $last->[ROUTE_ANGLE] || $last->[ROUTE_ANGLE] < $route_straight_angle) {
	    $last->[ROUTE_NAME] .= ", " . $this->[ROUTE_NAME]
		if $route_with_name->[$i-1]->[ROUTE_NAME] ne $this->[ROUTE_NAME];
	    $last->[ROUTE_DIST] += $this->[ROUTE_DIST];
	    $last->[ROUTE_ANGLE] = $this->[ROUTE_ANGLE];
	    $last->[ROUTE_DIR] = $this->[ROUTE_DIR];
	    $last->[ROUTE_ARRAYINX][1] = $this->[ROUTE_ARRAYINX][1];
	    # combine ROUTE_EXTRA?
	} else {
	    push @res, Storable::dclone($this);
	}
    }
    @res;
}

sub neighbor_by_direction {
    my($self, $p, $angle_or_direction, %args) = @_;
    die "Unknown options: " . join(" ", %args) if %args;

    require BBBikeUtil;
    require BBBikeCalc;

    my $angle;
    if ($angle_or_direction !~ m{^-?\d+(?:\.\d+)?$}) {
	$angle = _direction_to_deg($angle_or_direction);
	if (!defined $angle) {
	    die "Invalid direction '$angle_or_direction' (please use lower case English direction abbrevs)";
	}
    } else {
	$angle = BBBikeCalc::norm_deg($angle_or_direction);
    }

    my $net = $self->{Net};
    if (!$net) {
	die "Did you call make_net?";
    }

    my($px,$py) = split /,/, $p;

    my @neighbor_results;
    while(my($neighbor,$dist) = each %{ $net->{$p} }) {
	my($nx,$ny) = split /,/, $neighbor;
	my $neighbor_arc = BBBikeCalc::norm_arc(BBBikeUtil::pi()/2-atan2($ny-$py,$nx-$px));
	my $diff = BBBikeUtil::rad2deg(_norm_arc_180(BBBikeUtil::deg2rad($angle) - $neighbor_arc));
	my $delta = abs($diff);
	my $side = $diff > 0 ? 'l' : $diff < 0 ? 'r' : '';
	push @neighbor_results, { delta => $delta, coord => $neighbor, side => $side};
    }

    sort { $a->{delta} <=> $b->{delta} } @neighbor_results;
}

# XXX unfortunately BBBikeCalc is not usable here :-(
use constant _direction_to_deg_CAKE => 22.5;
sub _direction_to_deg {
    my $dir = shift;
    return {'n'   => _direction_to_deg_CAKE*0,
	    'nne' => _direction_to_deg_CAKE*1,
	    'ne'  => _direction_to_deg_CAKE*2,
	    'ene' => _direction_to_deg_CAKE*3,
	    'e'   => _direction_to_deg_CAKE*4,
	    'ese' => _direction_to_deg_CAKE*5,
	    'se'  => _direction_to_deg_CAKE*6,
	    'sse' => _direction_to_deg_CAKE*7,
	    's'   => _direction_to_deg_CAKE*8,
	    'ssw' => _direction_to_deg_CAKE*9,
	    'sw'  => _direction_to_deg_CAKE*10,
	    'wsw' => _direction_to_deg_CAKE*11,
	    'w'   => _direction_to_deg_CAKE*12,
	    'wnw' => _direction_to_deg_CAKE*13,
	    'nw'  => _direction_to_deg_CAKE*14,
	    'nnw' => _direction_to_deg_CAKE*15,
	   }->{$dir};
}

# Return value -pi..pi
sub _norm_arc_180 {
    my($arc) = @_;
    require BBBikeUtil;
    if ($arc < -BBBikeUtil::pi()) {
	$arc + 2*BBBikeUtil::pi();
    } elsif ($arc > BBBikeUtil::pi()) {
	$arc + 2*BBBikeUtil::pi();
    } else {
	$arc;
    }
}


sub next_neighbors {
    my($self, $from_p, $center_p, %args) = @_;
    die "Unknown options: " . join(" ", %args) if %args;

    require BBBikeUtil;
    require BBBikeCalc;

    my($from_px,$from_py) = split /,/, $from_p;
    my($center_px,$center_py) = split /,/, $center_p;

    my $angle = BBBikeUtil::rad2deg(BBBikeCalc::norm_arc(BBBikeUtil::pi()/2-atan2($center_py-$from_py, $center_px-$from_px)));
    $self->neighbor_by_direction($center_p, $angle);
}

1;

__END__
