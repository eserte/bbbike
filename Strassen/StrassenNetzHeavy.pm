# -*- perl -*-

#
# $Id: StrassenNetzHeavy.pm,v 1.10 2003/06/28 14:30:15 eserte Exp $
#
# Copyright (c) 1995-2003 Slaven Rezic. All rights reserved.
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License, see the file COPYING.
#
# Mail: slaven@rezic.de
# WWW:  http://bbbike.sourceforge.net
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
### AutoLoad Sub
sub make_net_cat {
    my($self, %args) = @_;
    my $obey_dir    = $args{-obeydir} || 0;
    my $do_net2name = $args{-net2name} || 0;
    my $multiple    = $args{-multiple} || 0;
    my $cacheable   = defined $args{-usecache} ? $args{-usecache} : $Strassen::Util::cacheable;
    my $args2filename = join("_", $obey_dir, $do_net2name, $multiple);

    my $cachefile;
    if ($cacheable) {
	my @src = $self->sourcefiles;
	$cachefile = $self->get_cachefile;
	my $net2name = Strassen::Util::get_from_cache("net2name_" . $args2filename . "_$cachefile", \@src);
	my $net = Strassen::Util::get_from_cache("net_" . $args2filename . "_$cachefile", \@src);
	if (defined $net2name && defined $net) {
	    $self->{Net2Name} = $net2name;
	    $self->{Net} = $net;
	    if ($VERBOSE) {
		warn "Using cache for $cachefile\n";
	    }
	    return;
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
	if ($ret->[Strassen::CAT()] =~ /^(.*);(.*)$/) {
	    ($cat_hin, $cat_rueck) = ($1, $2);
	} else {
	    $cat_hin = $cat_rueck = $ret->[Strassen::CAT()];
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
# For $type only "N_RW" is defined now:
#    H    => H, B or HH without cycle path
#    H_RW => same with
#    N    => N or NN without cycle path
#    N_RW => same with
# %args: may be UseCache => $boolean
### AutoLoad Sub
sub make_net_cyclepath {
    my($self, $cyclepath, $type, %args) = @_;

    my $args2filename = "$type";

    my $cachefile;
    my $cacheable = defined $args{UseCache} ? $args{UseCache} : $Strassen::Util::cacheable;
    if ($cacheable) {
	my @src = $self->sourcefiles;
	$cachefile = $self->get_cachefile;
	my $net = Strassen::Util::get_from_cache("net_" . $args2filename . "_$cachefile", \@src);
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
	my $i;
	for($i = 0; $i < $#kreuzungen; $i++) {
	    my $str_cat   = ($cat =~ /^(H|HH|B)$/ ? 'H' : 'N');
	    if (exists $c_net->{$kreuzungen[$i]}{$kreuzungen[$i+1]}) {
		$net->{$kreuzungen[$i]}{$kreuzungen[$i+1]} = $str_cat."_RW";
	    } else {
		$net->{$kreuzungen[$i]}{$kreuzungen[$i+1]} = $str_cat;
	    }
	    if (exists $c_net->{$kreuzungen[$i+1]}{$kreuzungen[$i]}) {
		$net->{$kreuzungen[$i+1]}{$kreuzungen[$i]} = $str_cat."_RW";
	    } else {
		$net->{$kreuzungen[$i+1]}{$kreuzungen[$i]} = $str_cat;
	    }
	}
    }

    if ($cacheable) {
	Strassen::Util::write_cache($net, "net_" . $args2filename . "_$cachefile", -modifiable => 1);
	if ($VERBOSE) {
	    warn "Wrote cache ($cachefile)\n";
	}
    }

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
### AutoLoad Sub
sub add_umsteigebahnhoefe {
    my($self, $bhf_obj, %args) = @_;

    # XXX untested
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
	    my($x1,$y1) = split(/,/, $coords);
	    foreach my $p (@{ $bahnhoefe{$name} }) {
		if ($coords ne $p) {
		    my($x2,$y2) = split(/,/, $p);
		    my $entf = Strassen::Util::strecke([$x1,$y1],[$x2,$y2]);
		    $self->store_to_hash($self->{Net}, $coords, $p, $entf);
		    $self->store_to_hash($self->{Net}, $p, $coords, $entf);
		}
	    }
	    push @{ $bahnhoefe{$name} }, $coords;
	} else {
	    $bahnhoefe{$name} = [$coords];
	}
    }
}

# see remove_from_deleted and add_to_deleted
### AutoLoad Sub
sub toggle_deleted_line {
    my($net, $xy1, $xy2, $on_callback, $off_callback) = @_;
    if (exists $net->{_Deleted}{$xy1}{$xy2} ||
	exists $net->{_Deleted}{$xy2}{$xy1}) {
	$net->remove_from_deleted($xy1,$xy2,$off_callback);
    } else {
	$net->add_to_deleted($xy1,$xy2,$on_callback);
    }
}

### AutoLoad Sub
sub remove_from_deleted {
    my($net, $xy1, $xy2, $off_callback) = @_;
    $net->{Net}{$xy1}{$xy2} = $net->{_Deleted}{$xy1}{$xy2}
	if exists $net->{_Deleted}{$xy1}{$xy2};
    delete $net->{_Deleted}{$xy1}{$xy2};
    $net->{Net}{$xy2}{$xy1} = $net->{_Deleted}{$xy2}{$xy1}
	if exists $net->{_Deleted}{$xy2}{$xy1};
    delete $net->{_Deleted}{$xy2}{$xy1};
    $off_callback->($xy1, $xy2) if ($off_callback);
}

### AutoLoad Sub
sub remove_all_from_deleted {
    my($net, $off_callback) = @_;
    while(my($xy1,$v1) = each %{$net->{_Deleted}}) {
	while(my($xy2,$v2) = each %$v1) {
	    $net->remove_from_deleted($xy1,$xy2,$off_callback);
	}
    }
}

### AutoLoad Sub
sub add_to_deleted {
    my($net, $xy1, $xy2, $on_callback) = @_;
    $net->{_Deleted}{$xy1}{$xy2} = $net->{Net}{$xy1}{$xy2}
	if exists $net->{Net}{$xy1}{$xy2};
    $net->{_Deleted}{$xy2}{$xy1} = $net->{Net}{$xy2}{$xy1}
	if exists $net->{Net}{$xy2}{$xy1};
    $net->del_net($xy1, $xy2, 2);
    $on_callback->($xy1, $xy2) if $on_callback;;
}

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
    my $s = UNIVERSAL::isa($filename, 'Strassen')
	    ? $filename : Strassen->new($filename);
    $s->init;
    my %set;
    while(1) {
	my $r = $s->next;
	last if @{ $r->[Strassen::COORDS()] } == 0;
	die "Coordinate count should be 2, but is @{[ scalar @{ $r->[Strassen::COORDS()] } ]}. The output file should be generated by the 'user deletions' feature of bbbike. Position " . $s->pos
	    if @{ $r->[Strassen::COORDS()] } != 2;
	$net->add_to_deleted($r->[Strassen::COORDS()]->[0],
			     $r->[Strassen::COORDS()]->[1],
			     $on_callback);
	$set{$r->[Strassen::COORDS()]->[0]}->{$r->[Strassen::COORDS()]->[1]}++;
    }
    if (!$do_merge) {
	while(my($k1,$v1) = each %{ $net->{_Deleted} }) {
	    while(my($k2,$v2) = each %$v1) {
		if (!exists $set{$k1}->{$k2} &&
		    !exists $set{$k2}->{$k1}) {
		    $net->remove_from_deleted($k1,$k2, $off_callback);
		}
	    }
	}
    }
}

### AutoLoad Sub
sub create_user_deletions_object {
    my $net = shift;
    my $s = Strassen->new;
    my %set;
    while(my($k1,$v1) = each %{ $net->{_Deleted} }) {
	while(my($k2,$v2) = each %$v1) {
	    if (!exists $set{$k1}->{$k2} &&
		!exists $set{$k2}->{$k1}) {
		$s->push(["userdel", [$k1,$k2], BLOCKED_COMPLETE]);
		$set{$k1}->{$k2}++;
	    }
	}
    }
    $s;
}

### AutoLoad Sub
sub save_user_deletions {
    my($net, $filename) = @_;
    my $s = $net->create_user_deletions_object;
    $s->write($filename);
}

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
	my $r = $s->next;
	my $c = $r->[Strassen::COORDS()];
	last if @$c == 0;
	# XXX only for COORDS == 2 now (generated from user_deletions in bbbike)
	$net->{$c->[0]}{$c->[1]} = $r->[Strassen::CAT()];
	$net->{$c->[1]}{$c->[0]} = $r->[Strassen::CAT()];
    }
}

1;

__END__
