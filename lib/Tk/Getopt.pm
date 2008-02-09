# -*- perl -*-

#
# $Id: Getopt.pm,v 1.64 2008/02/08 22:23:56 eserte Exp $
# Author: Slaven Rezic
#
# Copyright (C) 1997,1998,1999,2000,2003,2007,2008 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: srezic@cpan.org
# WWW:  http://www.rezic.de/eserte/
#

package Tk::Getopt;
require 5.005; # calling CODE refs
use strict;
use vars qw($loadoptions $VERSION $x11_pass_through
	    $CHECKMARK_OFF $CHECKMARK_ON
	    $FILE_IMAGE $CURR_GEOMETRY_IMAGE $DEBUG
	   );
use constant OPTNAME  => 0;
use constant OPTTYPE  => 1;
use constant DEFVAL   => 2;
use constant OPTEXTRA => 3;

use Carp qw();

$VERSION = '0.49_54';
$VERSION = eval $VERSION;

$DEBUG = 0;
$x11_pass_through = 0;

sub new {
    my($pkg, %a) = @_;
    my $self = {};

    $self->{'options'} = delete $a{'-options'} if exists $a{'-options'};

    if (exists $a{'-opttable'}) {
	$self->{'opttable'} = delete $a{'-opttable'};
	foreach (@{$self->{'opttable'}}) {
	    # Convert from new style without hash for extra options for
	    # internal operation.
	    # ['opt', '=s', 'defval', 'x' => 'y', 'z' => 'a', ...] into
	    # ['opt', '=s', 'defval', {'x' => 'y', 'z' => 'a', ...}]
	    if (ref $_ eq 'ARRAY' and
		defined $_->[OPTEXTRA] and
		ref $_->[OPTEXTRA] ne 'HASH') {
		if ((@$_ - OPTEXTRA) % 2 != 0) {
		    warn "Odd number of elements in definition for " . $_->[OPTNAME];
		}
		my %h = splice @$_, OPTEXTRA;
		$_->[OPTEXTRA] = \%h;
	    }
	    # Handle aliases
	    if (ref $_ eq 'ARRAY' && $_->[OPTNAME] =~ /\|/) {
		my($opt, @aliases) = split(/\|/, $_->[OPTNAME]);
		$_->[OPTNAME] = $opt;
		push(@{$_->[OPTEXTRA]{'aliases'}}, @aliases);
	    }
	}
    } elsif (exists $a{'-getopt'}) {
	# build opttable from -getopt argument
	my @optionlist;
	my $genprefix = "(--|-|\\+)";
	if (ref $a{'-getopt'} eq 'HASH') {
	    # convert hash to array
	    @optionlist
	      = map { ($_, $a{'-getopt'}->{$_}) } keys %{$a{'-getopt'}};
	} else {
	    @optionlist = @{$a{'-getopt'}};
	}
	delete $a{'-getopt'};
	# check if first argument is hash reference
	if (ref $optionlist[0] eq 'HASH') {
	    $self->{'options'} = shift @optionlist;
	}
	while (@optionlist > 0) {
	    my $opt = shift @optionlist;
	    # Strip leading prefix so people can specify "--foo=i"
	    # if they like.
	    $opt = $2 if $opt =~ /^($genprefix)+(.*)$/;

	    if ($opt !~ /^(\w+[-\w|]*)?(!|[=:][infse][@%]?)?$/) {
		warn "Error in option spec: \"", $opt, "\"\n";
		next;
	    }
	    my($o, $c) = ($1, $2);
	    $c = '' unless defined $c;
	    my @aliases;
	    if ($o =~ /\|/) {
		# Handle alias names
		@aliases = split(/\|/, $o);
		$o = shift @aliases;
	    }
	    my $varref;
	    # If no linkage is supplied in the @optionlist, copy it from
	    # the userlinkage ($self->{'options'}) if available.
	    if (defined $self->{'options'} && !ref $optionlist[0]) {
		$varref = (exists $self->{'options'}{$o} ?
			   $self->{'options'}{$o} :
			   \$self->{'options'}{$o});
	    } elsif (ref $optionlist[0]) {
		# link to global variable
		$varref = shift @optionlist;
	    }
	    my %a;
	    if (defined $varref) {
		if (ref $varref eq 'CODE') {
		    my $code = $varref;
		    $a{'callback'} = sub {
			if ($self->{'options'}{$o}) {
			    &$code;
			}
		    };
		    $varref = \$self->{'options'}{$o};
		}
		if (ref($varref) =~ /^(SCALAR|HASH|ARRAY)$/) {
		    $a{'var'} = $varref;
		} else {
		    die "Can't handle variable reference of type "
		      . ref $varref;
		}
	    }
	    if (@aliases) {
		$a{'alias'} = \@aliases;
	    }
	    push(@{$self->{'opttable'}}, [$o, $c, undef, \%a]);
	}
    } else {
	die "No opttable array ref or getopt hash ref";
    }

    $self->{'caller'}         = (caller)[0];
    $self->{'filename'}       = delete $a{'-filename'};
    $self->{'nosafe'}         = delete $a{'-nosafe'};
    $self->{'useerrordialog'} = delete $a{'-useerrordialog'};

    die "Unrecognized arguments: " . join(" ", %a) if %a;

    bless $self, $pkg;
}

# Return a list with all option names, that is, section labels and
# descriptions are ignored.
sub _opt_array {
    my $self = shift;
    my @res;
    foreach (@{$self->{'opttable'}}) {
	push @res, $_
	    if ref $_ eq 'ARRAY' and
	       $_->[OPTNAME] ne '';
    }
    @res;
}

# Return a reference to the option variable given by $opt
sub varref {
    my($self, $opt) = @_;
    if($opt->[OPTEXTRA]{'var'}) {
	$opt->[OPTEXTRA]{'var'};
    } elsif ($self->{'options'}) {
	\$self->{'options'}{$opt->[OPTNAME]};
    } else {
	# Link to global $opt_XXX variable.
	# Make sure a valid perl identifier results.
	my $v;
	($v = $opt->[OPTNAME]) =~ s/\W/_/g;
	eval q{\$} . $self->{'caller'} . q{::opt_} . $v; # XXX @, %
    }
}
# Formerly the varref method was private:
sub _varref { shift->varref(@_) }

sub optextra {
    my($self, $opt, $arg) = @_;
    $opt->[OPTEXTRA]{$arg};
}

sub _is_separator {
    my $opt = shift;
    defined $opt->[OPTNAME] && $opt->[OPTNAME] eq '' &&
    defined $opt->[DEFVAL]  && $opt->[DEFVAL] eq '-';
}

sub set_defaults {
    my $self = shift;
    my $opt;
    foreach $opt ($self->_opt_array) {
	if (defined $opt->[DEFVAL]) {
	    my $ref = ref $self->varref($opt);
	    if      ($ref eq 'ARRAY') {
		@ {$self->varref($opt)} = @{ $opt->[DEFVAL] };
	    } elsif ($ref eq 'HASH') {
		% {$self->varref($opt)} = %{ $opt->[DEFVAL] };
	    } elsif ($ref eq 'SCALAR') {
		$ {$self->varref($opt)} = $opt->[DEFVAL];
	    } else {
		die "Invalid reference type for option $opt->[OPTNAME] while setting the default value (maybe you should specify <undef> as the default value)";
	    }
	}
    }
}

sub load_options {
    my($self, $filename) = @_;
    $filename = $self->{'filename'} if !$filename;
    return if !$filename;
    if ($self->{'nosafe'}) {
	require Safe;
	my $c = new Safe;
	$c->share('$loadoptions');
	if (!$c->rdo($filename)) {
	    warn "Can't load $filename";
	    return undef;
	}
    } else {
	eval {do $filename};
	if ($@) {
	    warn $@;
	    return undef;
	}
    }

    my $opt;
    foreach $opt ($self->_opt_array) {
	if (exists $loadoptions->{$opt->[OPTNAME]}) {
	    if (ref $self->varref($opt) eq 'CODE') {
		$self->varref($opt)->($opt, $loadoptions->{$opt->[OPTNAME]}) if $loadoptions->{$opt->[OPTNAME]};
	    } elsif (ref $self->varref($opt) eq 'ARRAY' &&
		     ref $loadoptions->{$opt->[OPTNAME]} eq 'ARRAY') {
		@{ $self->varref($opt) } = @{ $loadoptions->{$opt->[OPTNAME]} };
	    } elsif (ref $self->varref($opt) eq 'HASH' &&
		     ref $loadoptions->{$opt->[OPTNAME]} eq 'HASH') {
		%{ $self->varref($opt) } = %{ $loadoptions->{$opt->[OPTNAME]} };
	    } else {
		$ {$self->varref($opt)} = $loadoptions->{$opt->[OPTNAME]};
	    }
	}
    }
    1;
}

sub save_options {
    my($self, $filename) = @_;
    $filename = $self->{'filename'} if !$filename;
    die "Saving disabled" if !$filename;
    eval "require Data::Dumper";
    if ($@) {
	warn $@;
	$self->my_die("No Data::Dumper available, cannot save options.\n");
    } else {
	if (open(OPT, ">$filename")) {
	    my %saveoptions;
	    my $opt;
	    foreach $opt ($self->_opt_array) {
		if (!$opt->[OPTEXTRA]{'nosave'}) {
		    my $ref;
		    if ($opt->[OPTEXTRA]{'savevar'}) {
			$ref = $opt->[OPTEXTRA]{'savevar'};
		    } else {
			$ref = $self->varref($opt);
		    }
		    if (ref($ref) eq 'SCALAR') {
			$saveoptions{$opt->[OPTNAME]} = $$ref;
		    } elsif (ref($ref) =~ /^(HASH|ARRAY)$/) {
			$saveoptions{$opt->[OPTNAME]} = $ref;
		    }
		}
	    }
	    local $Data::Dumper::Sortkeys = $Data::Dumper::Sortkeys = 1;
	    local $Data::Dumper::Indent = $Data::Dumper::Indent = 1;
	    if (Data::Dumper->can('Dumpxs')) {
		# use faster version of Dump
		print OPT
		  Data::Dumper->Dumpxs([\%saveoptions], ['loadoptions']);
	    } else {
		print OPT
		  Data::Dumper->Dump([\%saveoptions], ['loadoptions']);
	    }
	    close OPT;
	    warn "Options written to $filename" if $DEBUG;
	    1;
	} else {
	    $self->my_die("Writing to config file <$filename> failed: $!\n");
	    undef;
	}
    }
}

sub get_options {
    my $self = shift;
    my %getopt;
    my $opt;
    foreach $opt ($self->_opt_array) {
	$getopt{_getopt_long_string($opt->[OPTNAME], $opt->[OPTTYPE])} =
	  $self->varref($opt);
	# process aliases
	foreach (@{$opt->[OPTEXTRA]{'alias'}}) {
	    $getopt{_getopt_long_string($_, $opt->[OPTTYPE])} =
	      $self->varref($opt);
	}
    }
    require Getopt::Long;
    # XXX anders implementieren ... vielleicht die X11-Optionen zusätzlich
    # in die %getopt-Liste reinschreiben?
    if ($x11_pass_through) {
	Getopt::Long::config('pass_through');
    }
    my $res = Getopt::Long::GetOptions(%getopt);
    # Hack to pass standard X11 options (as defined in Tk::CmdLine)
    if ($x11_pass_through) {
	eval {
	    require Tk::CmdLine;
	    if ($Tk::CmdLine::VERSION >= 3.012) {
		# XXX nicht ausgetestet
		my @args = @ARGV;
		while (@args && $args[0] =~ /^-(\w+)$/) {
		    my $sw = $1;
		    return 0 if !$Tk::CmdLine::Method{$sw};
		    if ($Tk::CmdLine::Method{$sw} ne 'Flag_') {
			shift @args;
		    }
		    shift @args;
		}
	    } else {
		my $flag_ref = \&Tk::CmdLine::flag;
		my @args = @ARGV;
		while (@args && $args[0] =~ /^-(\w+)$/) {
		    my $sw = $1;
		    return 0 if !$Tk::CmdLine::switch{$sw};
		    if ($Tk::CmdLine::switch{$sw} ne $flag_ref) {
			shift @args;
		    }
		    shift @args;
		}
	    }
	    $res = 1;
	};
	warn $@ if $@;
    }
    $res;
}

# Builds a string for Getopt::Long. Arguments are option name and option
# type (e.g. '!' or '=s').
sub _getopt_long_string {
    my($option, $type) = @_;
    $option . (length($option) == 1 &&
	       (!defined $type || $type eq '' || $type eq '!')
	       ? '' : $type);
}

# Prints option name with one or two dashes
sub _getopt_long_dash {
    my $option = shift;
    (length($option) == 1 ? '' : '-') . "-$option";
}

sub usage {
    my $self = shift;
    my $usage = "Usage: $0 [options]\n";
    my $opt;
    foreach $opt ($self->_opt_array) {
	# The following prints all options as a comma-seperated list
	# with one or two dashes, depending on the length of the option.
	# Options are sorted by length.
 	$usage .= join(', ',
 		       sort { length $a <=> length $b }
 		       map { _getopt_long_dash($_) }
 		       map { ($opt->[OPTTYPE] eq '!' ? "[no]" : "") . $_ }
		       ($opt->[OPTNAME], @{$opt->[OPTEXTRA]{'alias'}}));
	$usage .= "\t";
	$usage .= $opt->[OPTEXTRA]{'help'}              if $opt->[OPTEXTRA]{'help'};
	$usage .= " (default: " . $opt->[DEFVAL] . ") " if $opt->[DEFVAL];
	$usage .= "\n";
    }
    $usage;
}

sub process_options {
    my($self, $former, $fromgui) = @_;
    my $bag = {};
    foreach my $optdef ($self->_opt_array) {
	my $opt = $optdef->[OPTNAME];

	my $callback;
	if ($fromgui) {
	    $callback = $optdef->[OPTEXTRA]{'callback-interactive'};
	}
	if (!$callback) {
	    $callback = $optdef->[OPTEXTRA]{'callback'};
	}
	if ($callback) {
	    # no warnings here ... it would be too complicated to catch
	    # all undefined values
	    my $old_w = $^W;
	    local($^W) = 0;
	    # execute callback if value has changed
	    if (!(defined $former
		  && (!exists $former->{$opt}
		      || $ {$self->varref($optdef)} eq $former->{$opt}))) {
		local($^W) = $old_w; # fall back to original value
		&$callback(optdef => $optdef, bag => $bag);
	    }
	}
	if ($optdef->[OPTEXTRA]{'strict'} &&
	    UNIVERSAL::isa($optdef->[OPTEXTRA]{'choices'},'ARRAY')) {
	    # check for valid values (valid are: choices and default value)
	    my $v = $ {$self->varref($optdef)};
	    my @choices = @{$optdef->[OPTEXTRA]{'choices'}};
	    push(@choices, $optdef->[DEFVAL]) if defined $optdef->[DEFVAL];
	    my $seen;
	    for my $choice (@choices) {
		my $value = (ref $choice eq 'ARRAY' ? $choice->[1] : $choice);
		if ($value eq $v) {
		    $seen = 1;
		    last;
		}
	    }
	    if (!$seen) {
		if (defined $former) {
		    warn "Not allowed: " . $ {$self->varref($optdef)}
		       . " for -$opt. Using old value $former->{$opt}";
		    $ {$self->varref($optdef)} = $former->{$opt};
		} else {
		    die "Not allowed: "
		      . $ {$self->varref($optdef)} . " for -$opt\n"
		      . "Allowed is only: " . join(", ", @choices);
		}
	    }
	}
    }
}

sub my_die {
    my($self, $msg, $is_safe) = @_;
    my $use_tk;
    if ($self->{'useerrordialog'} && defined &Tk::MainWindow::Existing) {
	for my $mw (Tk::MainWindow::Existing()) {
	    if (Tk::Exists($mw)) {
		$use_tk = $mw;
		last;
	    }
	}
	if ($use_tk && !defined $is_safe) {
	    for(my $i=0; $i<100; $i++) {
		my(undef,undef,undef,$subroutine) = caller($i);
		last if !defined $subroutine;
		if ($subroutine eq '(eval)') {
		    $use_tk = 0;
		    last;
		}
	    }
	}
    }
    if ($use_tk) {
	eval {
	    $use_tk->messageBox(-icon    => "error",
				-message => $msg,
				-title   => "Error",
			       );
	};
	if ($@) {
	    Carp::croak($msg);
	}
    } else {
	Carp::croak($msg);
    }
}

# try to work around weird browse entry
sub _fix_layout {
    my($self, $frame, $widget, %args) = @_;
    my($w, $real_w);
    if ($Tk::VERSION < 804) {
	my $f = $frame->Frame;
	$f->Label->pack(-side => "left"); # dummy
	$real_w = $f->$widget(%args)->pack(-side => "left", -padx => 1);
	$w = $f;
    } else {
	$w = $real_w = $frame->$widget(%args);
    }
    ($w, $real_w);
}

sub _boolean_widget {
    my($self, $frame, $opt) = @_;
    ($self->_fix_layout($frame, "Checkbutton",
			-variable => $self->varref($opt)))[0];
}

sub _boolean_checkmark_widget {
    # XXX hangs with Tk800.014?!
    my($self, $frame, $opt) = @_;
    _create_checkmarks($frame);
    ($self->_fix_layout($frame, "Checkbutton",
			-variable => $self->varref($opt),
			-image => $CHECKMARK_OFF,
			-selectimage => $CHECKMARK_ON,
			-indicatoron => 0,
		       ))[0];
}

sub _number_widget {
    my($self, $frame, $opt) = @_;
    ($self->_fix_layout($frame, "Scale",
			-orient => 'horizontal',
			-from => $opt->[OPTEXTRA]{'range'}[0],
			-to => $opt->[OPTEXTRA]{'range'}[1],
			-showvalue => 1,
			-resolution => ($opt->[OPTTYPE] =~ /f/ ? 0 : 1),
			-variable => $self->varref($opt)
		       ))[0];
}

sub _integer_widget {
    my($self, $frame, $opt) = @_;
    if (exists $opt->[OPTEXTRA]{'range'}) {
	$self->_number_widget($frame, $opt);
    } else {
	$self->_string_widget($frame, $opt, -restrict => "=i");
    }
}

sub _float_widget {
    my($self, $frame, $opt) = @_;
    if (exists $opt->[OPTEXTRA]{'range'}) {
	$self->_number_widget($frame, $opt);
    } else {
	$self->_string_widget($frame, $opt, -restrict => "=f");
    }
}

sub _list_widget {
    my($self, $frame, $opt) = @_;
    if ($opt->[OPTEXTRA]{'strict'} && grep { ref $_ eq 'ARRAY' } @{$opt->[OPTEXTRA]{'choices'}}) {
	$self->_optionmenu_widget($frame, $opt);
    } else {
	$self->_browseentry_widget($frame, $opt);
    }
}

sub _browseentry_widget {
    my($self, $frame, $opt) = @_;
    require Tk::BrowseEntry;
    my %args = (-variable => $self->varref($opt));
    if ($opt->[OPTEXTRA]{'strict'}) {
	$args{-state} = "readonly";
    }
    my $w = $frame->BrowseEntry(%args);
    my %mapping;
    my @optlist = @{$opt->[OPTEXTRA]{'choices'}};
    unshift @optlist, $opt->[DEFVAL] if defined $opt->[DEFVAL];
    my $o;
    my %seen;
    foreach $o (@optlist) {
	if (!$seen{$o}) {
	    $w->insert("end", $o);
	    $seen{$o}++;
	}
    }
    $w;
}

sub _optionmenu_widget {
    my($self, $frame, $opt) = @_;
    require Tk::Optionmenu;
    my $varref = $self->varref($opt);
    # Have to remember value, otherwise Optionmenu would overwrite it...
    my $value = $$varref;
    my %args = (-variable => $varref,
		-options => $opt->[OPTEXTRA]{'choices'},
	       );
    my $w = $frame->Optionmenu(%args);
    if (defined $value) {
	my $label = $value;
	for my $choice (@{ $opt->[OPTEXTRA]{'choices'} }) {
	    if (ref $choice eq 'ARRAY' && $choice->[1] eq $value) {
		$label = $choice->[0];
	    }
	}
	$w->setOption($label, $value);
    }
    $w;
}

sub _string_widget {
    my($self, $frame, $opt, %args) = @_;
    if (exists $opt->[OPTEXTRA]{'choices'}) {
	$self->_list_widget($frame, $opt);
    } else {
	my($e, $ee) = $self->_fix_layout
	    ($frame, "Entry",
	     (defined $opt->[OPTEXTRA]{'length'}
	      ? (-width => $opt->[OPTEXTRA]{'length'}) : ()),
	     -textvariable => $self->varref($opt));
	if ($args{-restrict} || defined $opt->[OPTEXTRA]{'maxsize'}) {
	    my $restrict_int   = sub { $_[0] =~ /^([+-]?\d+|)$/ };
	    my $restrict_float = sub {
		$_[0] =~ /^(|([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?)$/
	    };
	    my $restrict_len   = sub {
		length $_[0] <= $opt->[OPTEXTRA]{'maxsize'}
	    };
	    eval {
		$ee->configure
		    (-validate => "all",
		     -vcmd => sub {
			 ($args{-restrict} ne "=i" || $restrict_int->($_[0]))
			     &&
			 ($args{-restrict} ne "=f" || $restrict_float->($_[0]))
			     &&
			 (!defined $opt->[OPTEXTRA]{'maxsize'} || $restrict_len->($_[0]))
		     });
	    };
	    warn $@ if $@;
	}
	$e;
    }
}

sub _dir_select {
    my($top, $curr_dir) = @_;

    if ($top->can("chooseDirectory")) {
	return $top->chooseDirectory(-initialdir => $curr_dir);
    }

    if (eval { require Tk::DirSelect; Tk::DirSelect->VERSION("1.03"); 1 }) {
	return $top->DirSelect(-directory => $curr_dir)->Show;
    }

    require Tk::DirTree;
    my $t = $top->Toplevel;
    $t->title("Choose directory:");
    my $ok = 0; # flag: "1" means OK, "-1" means cancelled

    # Create Frame widget before the DirTree widget, so it's always visible
    # if the window gets resized.
    my $f = $t->Frame->pack(-fill => "x", -side => "bottom");

    my $d;
    $d = $t->Scrolled('DirTree',
		      -scrollbars => 'osoe',
		      -width => 35,
		      -height => 20,
		      -selectmode => 'browse',
		      -exportselection => 1,
		      -browsecmd => sub { $curr_dir = shift;
					  if ($^O ne 'MSWin32') {
					      $curr_dir =~ s|^//|/|; # bugfix
					  }
				        },

		      # With this version of -command a double-click will
		      # select the directory
		      -command   => sub { $ok = 1 },

		      # With this version of -command a double-click will
		      # open a directory. Selection is only possible with
		      # the Ok button.
		      #-command   => sub { $d->opencmd($_[0]) },
		     )->pack(-fill => "both", -expand => 1);
    # Set the initial directory
    $d->chdir($curr_dir);

    $f->Button(-text => 'Ok',
	       -command => sub { $ok =  1 })->pack(-side => 'left');
    $f->Button(-text => 'Cancel',
	       -command => sub { $ok = -1 })->pack(-side => 'left');
    $t->OnDestroy(sub { $ok = -1 });
    $f->waitVariable(\$ok);
    $t->destroy if Tk::Exists($t);
    if ($ok == 1) {
	$curr_dir;
    } else {
	undef;
    }
}

sub _filedialog_widget {
    my($self, $frame, $opt, %args) = @_;
    my $subtype = (exists $args{'-subtype'} ? $args{'-subtype'} : 'file');
    my $topframe = $frame->Frame;
    my $e;
    if (exists $opt->[OPTEXTRA]{'choices'}) {
	require Tk::BrowseEntry;
	$e = $topframe->BrowseEntry(-variable => $self->varref($opt));
	my @optlist = @{$opt->[OPTEXTRA]{'choices'}};
	unshift(@optlist, $opt->[DEFVAL]) if defined $opt->[DEFVAL];
	my $o;
	foreach $o (@optlist) {
	    $e->insert("end", $o);
	}
    } else {
	if (!eval '
               use Tk::PathEntry;
               my $real_e;
               ($e, $real_e) = $self->_fix_layout($topframe, "PathEntry",
                                                  -textvariable => $self->varref($opt));
               # XXX Escape is already used for cancelling Tk::Getopt
               $real_e->bind("<$_>" => sub { $real_e->Finish }) for (qw/Return/);
               1;
           ') {
	    ($e) = $self->_fix_layout($topframe, "Entry",
				      -textvariable => $self->varref($opt));
	}
    }
    $e->pack(-side => 'left');

    my $b = $topframe->Button
      (_get_browse_args($topframe),
       -command => sub {
	   require File::Basename;
	   my($fd, $filedialog);
	   if ($Tk::VERSION >= 800) {
	       if ($subtype eq 'dir') {
		   $fd = '_dir_select';
	       } elsif ($subtype eq 'savefile') {
		   $fd = 'getSaveFile';
	       } elsif ($subtype eq 'file') {
		   $fd = 'getOpenFile';
	       } else {
		   die "Unknown subtype <$subtype>";
	       }
	   } else {
	       $fd = 'FileDialog';
	       eval {
		   die "nope" if $subtype eq 'dir';
		   require Tk::FileDialog;
	       };
	       if ($@) {
		   require Tk::FileSelect;
		   $fd = 'FileSelect';
	       }
	       # XXX set FileDialog options via $opt->[3]{'filedialog_opt'}
	       if ($fd eq 'FileDialog') {
		   $filedialog = $topframe->FileDialog
		     (-Title => 'Select file');
	       } else {
		   $filedialog = $topframe->FileSelect;
	       }
	   }
	   my($dir, $base, $file);
	   my $act_val = $ {$self->varref($opt)};
	   if ($act_val) {
	       $dir  = File::Basename::dirname($act_val);
	       $base = File::Basename::basename($act_val);
	       $dir = '.' if (!-d $dir);

	       if ($fd =~ /^get(Open|Save)File$/) {
		   $file = $topframe->$fd(-initialdir => $dir,
					  -initialfile => $base,
					  -title => 'Select file',
# XXX erst ab 800.013 (?)
#						  -force => 1,
					 );
	       } elsif ($fd eq '_dir_select') {
		   $file = _dir_select($topframe, $dir);
	       } elsif ($fd eq 'FileDialog') {
		   $file = $filedialog->Show(-Path => $dir,
					     -File => $base);
	       } else {
		   if ($subtype eq 'dir') {
		       $file = $filedialog->Show(-directory => $dir,
						 -verify => [qw(-d)],
						);
		   } else {
		       $file = $filedialog->Show(-directory => $dir);
		   }
	       }
	   } else {
	       if ($fd =~ /^get(Open|Save)File$/) {
		   $file = $topframe->$fd(-title => 'Select file');
	       } elsif ($fd eq '_dir_select') {
		   require Cwd;
		   $file = _dir_select($topframe, Cwd::cwd());
	       } else {
		   if ($subtype eq 'dir') {
		       $file = $filedialog->Show(-verify => [qw(-d)]);
		   } else {
		       $file = $filedialog->Show;
		   }
	       }
	   }
	   if (defined $file && $file ne "") {
	       $ {$self->varref($opt)} = $file;
	   }
       });
    $b->pack(-side => 'left');
    $topframe;
}

sub _geometry_widget {
    my($self, $frame, $opt) = @_;
    my($topframe, $e) = $self->_fix_layout
	($frame,
	 'Entry',
	 (defined $opt->[OPTEXTRA]{'length'}
	  ? (-width => $opt->[OPTEXTRA]{'length'}) : ()),
	 -textvariable => $self->varref($opt));
    $topframe->Button(_get_curr_geometry_args($topframe),
		      -command => sub {
			  my $mw = $frame->MainWindow;
			  $e->delete(0, "end");
			  $e->insert("end", $mw->geometry);
		      },
		     )->pack(-side => "left");
    $topframe;
}

sub _color_widget {
    return shift->_string_widget(@_);

    # XXX funktioniert leider nicht...
    my($self, $frame, $opt) = @_;
    my($topframe, $e) = $self->_fix_layout
	($frame,
	 'Entry',
	 (defined $opt->[OPTEXTRA]{'length'}
	  ? (-width => $opt->[OPTEXTRA]{'length'}) : ()),
	 -textvariable => $self->varref($opt));
    if ($frame->can("chooseColor")) {
	$topframe->Button(-text => "...",
			  -padx => 0, -pady => 0,
			  -command => sub {
			      my $color = $frame->chooseColor;
#				  (-initialcolor => $e->get);
			      return unless defined $color;
			      $e->delete(0, "end");
			      $e->insert("end", $color);
			  },
			 )->pack(-side => "left");
    }
    $topframe;
}

sub _font_widget {
    my($self, $frame, $opt) = @_;
    my($topframe, $e) = $self->_fix_layout
	($frame,
	 'Entry',
	 (defined $opt->[OPTEXTRA]{'length'}
	  ? (-width => $opt->[OPTEXTRA]{'length'}) : ()),
	 -textvariable => $self->varref($opt));
    if (eval {require Tk::Font; require Tk::FontDialog; 1}) {
	$topframe->Button(-text => "...",
			  -padx => 0, -pady => 0,
			  -command => sub {
			      my $font = $frame->FontDialog
				  (-initfont => $e->get)->Show;
			      return unless defined $font;
			      $e->delete(0, "end");
			      $e->insert("end", $font->Pattern);
			  },
			 )->pack(-side => "left");
    }
    $topframe;
}

# Creates one page of the Notebook widget
# Arguments:
#   $current_page: Frame for drawing
#   $optnote: Notebook widget
#   $current_top: title of Notebook page
#   $optlist: list of options for this Notebook page
#   $balloon: Balloon widget
#   $msglist: (optional) list of messages for this Notebook page
sub _create_page {
    my($self, $current_page,
       $optnote, $current_top, $optlist,
       $balloon, $msglist) = @_;
    $current_page = $optnote->{$current_top} if !defined $current_page;
    my $opt;
    my $row = -1;

    my $msgobj;
    if (ref $msglist and
	exists $msglist->{$current_top} and
	$msglist->{$current_top} ne "") {
	$row++;
	$msgobj = $current_page->Label(-text => $msglist->{$current_top},
				       -justify => "left",
				       )->grid(-row => $row, -column => 0,
					       -columnspan => 3);
    }

    foreach $opt (@{$optlist->{$current_top}}) {
	my $f = $current_page;
	$row++;
	if (_is_separator($opt)) {
	    my $separator = $f->Frame(-height => 2,
				     )->grid(-row => $row,
					     -column => 0,
					     -columnspan => 3,
					     -pady => 3,
					     -padx => 3,
					     -sticky => "ew");
	    $separator->configure
		(-fg => $separator->cget(-bg),
		 -bg => $separator->Darken($separator->cget(-bg), 60));
	    next;
	}

	my $label;
	my $w;
	if (exists $opt->[OPTEXTRA]{'label'}) {
	    $label = $opt->[OPTEXTRA]{'label'};
	} else {
	    $label = $opt->[OPTNAME];
	    if ($label =~ /^(.*)-(.*)$/ && $1 eq $current_top) {
		$label = $2;
	    }
	}
	my $lw = $f->Label(-text => $label)->grid(-row => $row, -column => 0,
						  -sticky => 'w');
	if (exists $opt->[OPTEXTRA]{'widget'}) {
	    # own widget
	    $w = &{$opt->[OPTEXTRA]{'widget'}}($self, $f, $opt);
	} elsif (defined $opt->[OPTTYPE] &&
		 $opt->[OPTTYPE] eq '!' or $opt->[OPTTYPE] eq '') {
	    $w = $self->_boolean_widget($f, $opt); # XXX _checkmark_
	} elsif (defined $opt->[OPTTYPE] && $opt->[OPTTYPE] =~ /i/) {
	    $w = $self->_integer_widget($f, $opt);
	} elsif (defined $opt->[OPTTYPE] && $opt->[OPTTYPE] =~ /f/) {
	    $w = $self->_float_widget($f, $opt);
	} elsif (defined $opt->[OPTTYPE] && $opt->[OPTTYPE] =~ /s/) {
	    my $subtype = (defined $opt->[OPTEXTRA] &&
			   exists $opt->[OPTEXTRA]{'subtype'} ?
			   $opt->[OPTEXTRA]{'subtype'} : "");
	    if ($subtype eq 'file' ||
		$subtype eq 'savefile' ||
		$subtype eq 'dir') {
		$w = $self->_filedialog_widget($f, $opt, -subtype => $subtype);
	    } elsif ($subtype eq 'geometry') {
		$w = $self->_geometry_widget($f, $opt);
	    } elsif ($subtype eq 'color') {
		$w = $self->_color_widget($f, $opt);
	    } elsif ($subtype eq 'font') {
		$w = $self->_font_widget($f, $opt);
	    } else {
		$w = $self->_string_widget($f, $opt);
	    }
	} else {
	    warn "Can't generate option editor entry for $opt->[OPTNAME]";
	}
	if (defined $w) {
	    $w->grid(-row => $row, -column => 1, -sticky => 'w');
	}
	if (exists $opt->[OPTEXTRA]{'help'} && defined $balloon) {
	    $balloon->attach($w, -msg => $opt->[OPTEXTRA]{'help'})
		if defined $w;
	    $balloon->attach($lw, -msg => $opt->[OPTEXTRA]{'help'})
		if defined $lw;
	}
	if (exists $opt->[OPTEXTRA]{'longhelp'}) {
	    $f->Button(-text => '?',
		       -padx => 1,
		       -pady => 1,
		       -command => sub {
			   my $t = $f->Toplevel
			       (-title => $self->{_string}{"helpfor"}
				. " $label");
			   $t->Message(-text => $opt->[OPTEXTRA]{'longhelp'},
				     -justify => 'left')->pack;
			   $t->Button(-text => 'OK',
				      -command => sub { $t->destroy }
				     )->pack;
			   $t->Popup(-popover => "cursor");
		       })->grid(-row => $row, -column => 2, -sticky => 'w');
	}
    }
    $current_page->grid('columnconfigure', 3, -weight => 1);
    $current_page->grid('rowconfigure', ++$row, -weight => 1);
}

sub _do_undo {
    my($self, $undo_options) = @_;
    my $opt;
    foreach $opt ($self->_opt_array) {
	next if $opt->[OPTEXTRA]{'nogui'};
	if (exists $undo_options->{$opt->[OPTNAME]}) {
	    my $ref = ref $self->varref($opt);
	    if      ($ref eq 'ARRAY') {
		my @swap = @ {$self->varref($opt)};
		@ {$self->varref($opt)} = @{ $undo_options->{$opt->[OPTNAME]} };
		@{ $undo_options->{$opt->[OPTNAME]}} = @swap;
	    } elsif ($ref eq 'HASH') {
		my %swap = % {$self->varref($opt)};
		% {$self->varref($opt)} = %{ $undo_options->{$opt->[OPTNAME]} };
		%{ $undo_options->{$opt->[OPTNAME]}} = %swap;
	    } elsif ($ref eq 'SCALAR') {
		my $swap = $ {$self->varref($opt)};
		$ {$self->varref($opt)} = $undo_options->{$opt->[OPTNAME]};
		$undo_options->{$opt->[OPTNAME]} = $swap;
	    } else {
		die "Invalid reference type for option $opt->[OPTNAME]";
	    }
	}
    }
}

sub option_dialog {
    my($self, $top, %a) = @_;
    my $button_pressed;
    $a{'-buttonpressed'} = \$button_pressed;
    $a{'-wait'} = 1;
    $self->option_editor($top, %a);
    $button_pressed;
}

sub option_editor {
    my($self, $top, %a) = @_;
    my $callback  = delete $a{'-callback'};
    my $nosave    = delete $a{'-nosave'};
    my $buttons   = delete $a{'-buttons'};
    my $toplevel  = delete $a{'-toplevel'} || 'Toplevel';
    my $pack      = delete $a{'-pack'};
    my $transient = delete $a{'-transient'};
    my $use_statusbar = delete $a{'-statusbar'};
    my $wait      = delete $a{'-wait'};
    my $string    = delete $a{'-string'} || {};
    my $delay_page_create = (exists $a{'-delaypagecreate'}
			     ? delete $a{'-delaypagecreate'}
			     : 1);
    my $page      = delete $a{'-page'};
    my $button_pressed;
    if (exists $a{'-buttonpressed'}) {
	if (ref $a{'-buttonpressed'} ne "SCALAR") {
	    die "The value for the -buttonpressed option has to be a SCALAR reference, not a " . ref($a{'-buttonpressed'}) . "\n";
	}
	$button_pressed = delete $a{'-buttonpressed'};
    } else {
	# dummy
	$button_pressed = \do { my $dummy };
    }
    {
	my %defaults = ('optedit'    => 'Option editor',
			'undo'       => 'Undo',
			'lastsaved'  => 'Last saved',
			'save'       => 'Save',
			'defaults'   => 'Defaults',
			'ok'         => 'OK',
			'apply'      => 'Apply',
			'cancel'     => 'Cancel',
			'helpfor'    => 'Help for:',
			'oksave'     => 'OK',
		       );
	for my $key (keys %defaults) {
	    next if exists $string->{$key};
	    $string->{$key} = $defaults{$key};
	}
    }
    $self->{_string} = $string;

    if (defined $page) {
	$self->{'raised'} = $page;
    }

    # store old values for undo
    my %undo_options;
    my $opt;
    foreach $opt ($self->_opt_array) {
	next if $opt->[OPTEXTRA]{'nogui'};
	my $ref = ref $self->varref($opt);
	if      ($ref eq 'ARRAY') {
	    @{ $undo_options{$opt->[OPTNAME]} } = @ {$self->varref($opt)};
	} elsif ($ref eq 'HASH') {
	    %{ $undo_options{$opt->[OPTNAME]} } = % {$self->varref($opt)};
	} elsif ($ref eq 'SCALAR') {
	    $undo_options{$opt->[OPTNAME]}      = $ {$self->varref($opt)};
	} else {
	    die "Invalid reference type for option $opt->[OPTNAME]";
	}
    }

    require Tk;

    my $dont_use_notebook = 1;
    foreach $opt (@{$self->{'opttable'}}) {
	if (ref $opt ne 'ARRAY') { # found header
	    undef $dont_use_notebook;
	    last;
	}
    }
    if (!$dont_use_notebook) {
	eval { require Tk::NoteBook };
	$dont_use_notebook = 1 if $@;
    }

    my $dont_use_balloon;
    eval { require Tk::Balloon };
    $dont_use_balloon = 1 if $@;

    my $cmd = '$top->' . $toplevel . '(%a)';
    my $opt_editor = eval $cmd;
    die "$@ while evaling $cmd" if $@;
    $opt_editor->transient($transient) if $transient;
    eval { $opt_editor->configure(-title => $string->{optedit}) };

    my $opt_notebook = ($dont_use_notebook ?
			$opt_editor->Frame :
			$opt_editor->NoteBook(-ipadx => 6, -ipady => 6));
    $self->{Frame} = $opt_notebook;

    my($statusbar, $balloon);
    if (!$dont_use_balloon) {
	if ($use_statusbar) {
	    $statusbar = $opt_editor->Label;
	}
	$balloon = $opt_notebook->Balloon($use_statusbar
					  ? (-statusbar => $statusbar)
					  : ());
    }

    my $optlist = {};
    my $msglist = {};
    my $current_top;
    if ($dont_use_notebook) {
	$current_top = $string->{'optedit'};
	foreach $opt ($self->_opt_array) {
	    push(@{$optlist->{$current_top}}, $opt)
	      if !$opt->[OPTEXTRA]{'nogui'};
	}
	# XXX message missing
	$self->_create_page($opt_notebook, undef, $current_top,
			    $optlist, $balloon);
    } else {
	my @opttable = @{$self->{'opttable'}};
	unshift(@opttable, $string->{'optedit'})
	    if ref $opttable[OPTNAME] eq 'ARRAY'; # put head

	my $page_create_page;
	foreach $opt (@opttable) {
	    if (ref $opt ne 'ARRAY') {
		if (!$delay_page_create && $page_create_page) {
		    $page_create_page->();
		    undef $page_create_page;
		}

		my $label = $opt;
		$current_top = lc($label);
		my $c = $current_top;
		$optlist->{$c} = [];
		$msglist->{$c} = "";
		my $page_f;
		$page_create_page = sub {
		    $self->_create_page
			($page_f,
			 $opt_notebook, $c,
			 $optlist, $balloon, $msglist);
		};
		$page_f = $opt_notebook->add
		    ($c,
		     -label => $label,
		     -anchor => 'w',
		     ($delay_page_create?(-createcmd => $page_create_page):()),
		    );
            } elsif ($opt->[OPTNAME] eq '' && !_is_separator($opt)) {
		$msglist->{$current_top} = $opt->[DEFVAL];
	    } else {
		push @{$optlist->{$current_top}}, $opt
		    if !$opt->[OPTEXTRA]{'nogui'};
	    }
	}
	if (!$delay_page_create && $page_create_page) {
	    $page_create_page->();
	    undef $page_create_page;
	}

    }

    require Tk::Tiler;
    my $f;
    $f = $opt_editor->Tiler
      (-rows => 1,
       -columns => 1,
       -yscrollcommand => sub {
	   my $bw = $f->cget(-highlightthickness);
	   return if (!$f->{Sw});
	   my $nenner = int(($f->Width-2*$bw)/$f->{Sw});
	   return if (!$nenner);
	   my $rows = @{$f->{Slaves}}/$nenner;
	   return if (!$rows or !int($rows));
	   if ($rows/int($rows) > 0) {
	       $rows = int($rows)+1;
	   }
	   $f->GeometryRequest($f->Width,
			       2*$bw+$rows*$f->{Sh});
       });
    $f->bind('<Configure>' => sub {
		 if ($f->y + $f->height > $opt_editor->height) {
		     $opt_editor->geometry($opt_editor->width .
					   "x" .
					   ($f->height+$f->y));
		 }
	     });
    my @tiler_b;

    my %allowed_button;
    if ($buttons) {
	if (ref $buttons ne 'ARRAY') {
	    undef $buttons;
	} else {
	    %allowed_button = map { ($_ => 1) } @$buttons;
        }
    }

    if (!$buttons || $allowed_button{'ok'}) {
	my $ok_button
	    = $f->Button(-text => $string->{'ok'},
			 -underline => 0,
			 -command => sub {
			     $self->process_options(\%undo_options, 1);
                             if (!$dont_use_notebook) {
                                 $self->{'raised'} = $opt_notebook->raised();
                             }
                             $opt_editor->destroy;
			     $$button_pressed = 'ok';
                         }
                        );
        push @tiler_b, $ok_button;
    }

    if ($allowed_button{'oksave'}) {
	my $ok_button
	    = $f->Button(-text => $string->{'oksave'},
			 -underline => 0,
			 -command => sub {
			     $top->Busy;
			     eval {
				 $self->save_options;
				 $self->process_options(\%undo_options, 1);
				 if (!$dont_use_notebook) {
				     $self->{'raised'} = $opt_notebook->raised();
				 }
			     };
			     my $err = $@;
			     $top->Unbusy;
			     if ($err) {
				 $self->my_die($err, 'safe');
			     }
                             $opt_editor->destroy;
			     $$button_pressed = 'ok';
                         }
                        );
        push @tiler_b, $ok_button;
    }

    if (!$buttons || $allowed_button{'apply'}) {
	my $apply_button
	    = $f->Button(-text => $string->{'apply'},
			 -command => sub {
			     $self->process_options(\%undo_options, 1);
			 }
			);
	push @tiler_b, $apply_button;
    }
	
    my $cancel_button;
    if (!$buttons || $allowed_button{'cancel'}) {
	$cancel_button
	    = $f->Button(-text => $string->{'cancel'},
			 -command => sub {
			     $self->_do_undo(\%undo_options);
			     if (!$dont_use_notebook) {
				 $self->{'raised'} = $opt_notebook->raised();
			     }
			     $opt_editor->destroy;
			     $$button_pressed = 'cancel';
			 }
			);
	push @tiler_b, $cancel_button;
    }

    if (!$buttons || $allowed_button{'undo'}) {
	my $undo_button
	    = $f->Button(-text => $string->{'undo'},
			 -command => sub {
			     $self->_do_undo(\%undo_options);
			 }
			);
	push @tiler_b, $undo_button;
    }

    if ($self->{'filename'}) {
	if (!$buttons || $allowed_button{'lastsaved'}) {
	    my $lastsaved_button
		= $f->Button(-text => $string->{'lastsaved'},
			     -command => sub {
				 $top->Busy;
				 $self->load_options;
				 $top->Unbusy;
			     }
			    );
	    push @tiler_b, $lastsaved_button;
	}

	if (!$nosave && (!$buttons || $allowed_button{'save'})) {
	    my $save_button;
	    $save_button
		= $f->Button(-text => $string->{'save'},
			     -command => sub {
				 $top->Busy;
				 eval { $self->save_options };
				 if ($@ =~ /No Data::Dumper/) {
				     $save_button->configure(-state => 'disabled');
				 }
				 $top->Unbusy;
			     }
			    );
	    push @tiler_b, $save_button;
	}
    }

    if (!$buttons || $allowed_button{'defaults'}) {
	my $def_button
	    = $f->Button(-text => $string->{'defaults'},
			 -command => sub {
			     $self->set_defaults;
			 }
			);
	push @tiler_b, $def_button;
    }

    $f->Manage(@tiler_b);

    &$callback($self, $opt_editor) if $callback;

    if (!$dont_use_notebook && defined $self->{'raised'}) {
	$self->raise_page($self->{'raised'});
    }

    $opt_editor->bind('<Escape>' => sub { $cancel_button->invoke });

    $f->pack(-fill => 'x', -side => "bottom");
    $opt_notebook->pack(-expand => 1, -fill => 'both');
    if (defined $statusbar) {
	$statusbar->pack(-fill => 'x', -anchor => 'w');
    }

    if ($opt_editor->can('Popup')) {
	$opt_editor->withdraw;
	$opt_editor->Popup;
    }
    if ($wait) {
	if ($pack) {
	    $opt_editor->pack(@$pack);
	}
	my $wait_var = 1;
	$opt_editor->OnDestroy(sub { undef $wait_var });
	$opt_editor->waitVisibility unless $opt_editor->ismapped;
	$opt_editor->grab;
	$opt_editor->waitVariable(\$wait_var);
    }

    $opt_editor;
}

sub _create_checkmarks {
    my $w = shift;

    $CHECKMARK_ON  = $w->Photo(-data => <<EOF)
R0lGODdhDgAOAIAAAP///1FR+ywAAAAADgAOAAACM4SPFplGIXy0yDQK4aNFZAIlhI8QEQkUACKC
4EMERFAI3yg+wb+ICEQjMeGjRWQahfCxAAA7
EOF
      unless $CHECKMARK_ON;
    $CHECKMARK_OFF = $w->Photo(-data => <<EOF)
R0lGODdhDgAOAIAAAAAAAP///ywAAAAADgAOAAACDYyPqcvtD6OctNqrSAEAOw==
EOF
      unless $CHECKMARK_OFF;
}

sub _get_browse_args {
    my $w = shift;
    if (!defined $FILE_IMAGE) {
	require Tk::Pixmap;
	$FILE_IMAGE = $w->Pixmap(-file => Tk->findINC("openfolder.xpm"));
	$FILE_IMAGE = 0 if (!$FILE_IMAGE);
    }
    if ($FILE_IMAGE) {
	(-image => $FILE_IMAGE);
    } else {
	(-text => "Browse...");
    }
}

sub _get_curr_geometry_args {
    my $w = shift;
    if (!defined $CURR_GEOMETRY_IMAGE) {
	require Tk::Photo;
	$CURR_GEOMETRY_IMAGE = $w->Photo(-file => Tk->findINC("win.xbm"));
	$CURR_GEOMETRY_IMAGE = 0 if (!$CURR_GEOMETRY_IMAGE);
    }
    if ($CURR_GEOMETRY_IMAGE) {
	(-image => $CURR_GEOMETRY_IMAGE);
    } else {
	(-text => "Geom.");
    }
}

sub raise_page {
    my($self, $page) = @_;
    my $opt_notebook = $self->{Frame};
    $page = lc $page; # always lowercase in NoteBook internals
    $opt_notebook->raise($page);
}

1;

__END__

=head1 NAME

Tk::Getopt - User configuration window for Tk with interface to Getopt::Long

=head1 SYNOPSIS

    use Tk::Getopt;
    @opttable = (['opt1', '=s', 'default'], ['opt2', '!', 1], ...);
    $opt = new Tk::Getopt(-opttable => \@opttable,
                          -options => \%options,
			  -filename => "$ENV{HOME}/.options");
    $opt->set_defaults;     # set default values
    $opt->load_options;     # configuration file
    $opt->get_options;      # command line
    $opt->process_options;  # process callbacks, check restrictions ...
    print $options->{'opt1'}, $options->{'opt2'} ...;
    ...
    $top = new MainWindow;
    $opt->option_editor($top);

or using a L<Getopt::Long|Getopt::Long>-like interface

    $opt = new Tk::Getopt(-getopt => ['help'   => \$HELP,
				      'file:s' => \$FILE,
				      'foo!'   => \$FOO,
				      'num:i'  => \$NO,
				     ]);

or an alternative F<Getopt::Long> interface

    %optctl = ('foo' => \$foo,
	       'bar' => \$bar);
    $opt = new Tk::Getopt(-getopt => [\%optctl, "foo!", "bar=s"]);

=head1 DESCRIPTION

F<Tk::Getopt> provides an interface to access command line options via
L<Getopt::Long|Getopt::Long> and editing with a graphical user interface via a Tk window.

Unlike F<Getopt::Long>, this package uses a object oriented interface, so you
have to create a new F<Tk::Getopt> object with B<new>. Unlike other
packages in the Tk hierarchy, this package does not define a Tk widget. The
graphical interface is calles by the method B<option_editor>.

After creating an object with B<new>, you can parse command line options
by calling B<get_options>. This method calls itself
B<Getopt::Long::GetOptions>.

=head1 METHODS

=over 4

=item B<new Tk::Getopt(>I<arg_hash>B<)>

Constructs a new object of the class F<Tk::Getopt>. Arguments are
passed in a hash (just like Tk widgets and methods). There are many variants
to specify the option description. You can use an interface similar to
B<Getopt::Long::GetOptions> by using B<-getopt> or a more powerful
interface by using B<-opttable>. Internally, the option description will
be converted to the B<-opttable> interface. One of the arguments B<-getopt>
or B<-opttable> are mandatory.

The arguments for B<new> are:

=over 4

=item -getopt

B<-getopt> should be a reference to a hash or an array. This hash has the
same format as the argument to the B<Getopt::Long::GetOptions> function.
Look at L<Getopt::Long> for a detailed description. Note
also that not all of B<GetOptions> is implemented, see L<"BUGS"> for further
information.

Example:

    new Tk::Getopt(-getopt => [\%options,
                               "opt1=i", "opt2=s" ...]);

=item -opttable

B<-opttable> provides a more powerful interface. The options are
stored in variables named I<$opt_XXX> or in a hash when B<-options> is
given (see below). B<-opttable> should be a reference to an array
containing all options. Elements of this array may be strings, which
indicate the beginning of a new group, or array references describing
the options. The first element of this array is the name of the
option, the second is the type (C<=s> for string, C<=i> for integer,
C<!> for boolean, C<=f> for float etc., see L<Getopt::Long>) for a
detailed list. The third element is optional and contains the default
value (otherwise the default is undefined). Further elements are
optional too and describe more attributes. For a complete list of
these attributes refer to L<"OPTTABLE ARGUMENTS">.

If an option has no name, then the third element in the description
array will be used as an global message for the current option page.
This message can be multi-line.
Example:
    ['', '', 'This is an explanation for this option group.']

To insert horizontal lines, use:
    ['', '', '-']

Here is an example for a simple opttable:

    @opttable =
        ('First section',
	 ['', '', 'Section description'],
	 ['debug', '!',  0],
         ['age',   '=i', 18],

	 'Second section',
	 ['', '', 'Description for 2nd section'],
         ['browser', '=s', 'tkweb'],
         ['foo',     '=f', undef],
        );
    new Tk::Getopt(-opttable => \@opttable,
                   -options => \%options);

=item -options

This argument should be a reference to an (empty) hash. Options are set
into this hash. If this argument is missing, options will be stored in
variables named I<$opt_XXX>.

=item -filename

This argument is optional and specifies the filename for loading and saving
options.

=item -nosafe

If set to true, do not use a safe compartment when loading options
(see B<load_options>).

=item -useerrordialog

If set to true, then use an error dialog in user-relevant error
conditions. Otherwise, the error message is printed to STDERR. This
only includes errors which may happen in normal operation, but not
programming errors like specifying erroneous options. If no Tk context
is available (i.e. there is no MainWindow), then the error message
will also be printed to STDERR.

=back

=item B<set_defaults>

Sets default values. This only applies if the B<-opttable> variant is used.

=item B<load_options(>I<filename>B<)>

Loads options from file B<filename>, or, if not specified, from
object's filename as specified in B<new>. The loading is done in a safe
compartment ensure security.The loaded file should have a reference to a hash
named I<$loadoptions>.

=item B<save_options(>I<filename>B<)>

Writes options to file B<filename>, or, if not specified, from
object's filename as specified in B<new>. The saving is done with
L<Data::Dumper|Data::Dumper>. Since saving may fail, you should call this method inside
of C<eval {}> and check I<$@>. Possible exceptions are C<No Data::Dumper>
(cannot find the F<Data::Dumper> module) and C<Writing failed> (cannot
write to file).

=item B<get_options>

Gets options via B<GetOptions>. Returns the same value as B<GetOptions>, i.e.
0 indicates that the function detected one or more errors.

If you want to process options which does not appear in the GUI, you have
two alternatives:

=over 8

=item *

Use the B<-opttable> variant of the C<new> constructor and mark all
non-GUI options with B<nogui>, e.g.

    new Tk::Getopt(-opttable => ['not-in-gui', '!', undef,
                                 nogui => 1], ...)

=item *

Use I<Getopt::Long::passthrough> and process non-GUI options directly with
B<Getopt::Long::GetOptions>. The remaining args can be passed to
B<get_options>.

Example:

    use Tk::Getopt;
    use Getopt::Long;

    $Getopt::Long::passthrough = 1;
    GetOptions('options!' => \$preloadopt);
    $Getopt::Long::passthrough = 0;

    $opt = new Tk::Getopt( ... );
    $opt->get_options;

=back

=item B<usage>

Generates an usage string from object's opttable. The usage string is
constructed from the option name, default value and help entries.

=item B<process_options(>[I<undo_hash>]B<)>

Checks wheather given values are valid (if B<strict> is set) and calls
any callbacks specified by the B<sub> option. If B<undo_hash> is
given and the new value of an option did not change, no sub is called.

=item B<option_editor(>I<widget>, [I<arguments ...>]B<)>

Pops the option editor up. The editor provides facilitied for editing
options, undoing, restoring to their default valued and saving to the
default options file.

The option editor is non-modal. For a modal dialog, see below for the
L</option_dialog> method.

The first argument is the parent widget. Further optional arguments are
passed as a hash:

=over 8

=item -callback

Execute additional callback after creating the option editor. Arguments
passed to this callback are: reference to the F<Tk::Getopt> object and
a reference to the option editor window.

=item -nosave

Disable saving of options.

=item -savevar

When saving with the C<saveoptions> method, use the specified variable
reference instead of the C<-var> reference. This is useful if C<-var>
is a subroutine reference.

=item -buttons

Specify, which buttons should be drawn. It is advisable to draw at
least the OK and Cancel buttons. The default set looks like this:

    -buttons => [qw/ok apply cancel undo lastsaved save defaults/]

A minimal set could look like (here OK means accept and save)

    -buttons => [qw/oksave cancel/]

(and using less buttons is recommended).

=item -toplevel

Use another widget class instead of B<Toplevel> for embedding the
option editor, e.g. C<Frame> to embed the editor into another toplevel
widget (do not forget to pack the frame!). See also the C<-pack>
option below.

=item -transient

Set the transient flag on the toplevel window. See the description of
the transient method in L<Tk::Wm>.

    -transient => $mw

=item -pack

If using C<-toplevel> with a non-Toplevel widget (e.g. Frame) and
using the C<-wait> option, then packing have to be done through the
C<-pack> option. The argument to this option is a array reference of
pack options, e.g.

    $opt->option_editor(-toplevel => "Frame",
                        -wait => 1,
                        -pack => [-fill => "both", -expand => 1]);

=item -statusbar

Use an additional status bar for help messages.

=item -string

Change button labels and title. This argument should be a hash
reference with all or a subset of the following keys: C<optedit>,
C<undo>, C<lastsaved>, C<save>, C<defaults>, C<ok>, C<cancel>,
C<helpfor>.

=item -wait

Do not return immediately, but rather wait for the user pressing OK or Cancel.

=item -page

Raise the named notebook page (if grouping is used, see below).

=back

Since the option editor uses the C<NoteBook> widget, options may be
grouped in several pages. Grouping is only possible if using the
C<-opttable> variant of C<new>. Help messages are shown in balloons and,
if specified, in a statusbar.

B<option_editor> returns a reference to the created window.

Note: this method returns immediately to the calling program.

Buttons in the option editor window:

=over 4

=item OK

Accept options and close option editor window.

=item Cancel

Set old values and close option editor window.

=item Undo

Set old values. Further selections toggle between new and old values.

=item Last saved

Set last saved options. This button is not displayed if no filename was given
in C<new>.

=item Save

Save options to file. This button is not displayed if no filename was given
in C<new>.

=back

The option types are translated to following widgets:

=over 4

=item Boolean

B<Checkbutton> (B<_boolean_widget>)

=item Integer and Float

B<Scale>, if B<range> is set, otherwise either B<BrowseEntry> or B<Entry>
(B<_integer_widget>, B<_float_widget>).

=item String

B<BrowseEntry> if B<choices> is set, otherwise B<entry> (B<_string_widget>).
B<FileDialog> if B<subtype> is set to B<file>.

=back

=item B<option_dialog(>I<widget>, [I<arguments ...>]B<)>

This method works like L</option_editor>, but it shows the option
editor as a modal dialog. Additionaly, the return value is either
B<ok> or B<cancel> depending on how the user quits the editor.

=back

=head1 OPTTABLE ARGUMENTS

Additional attributes in an option description have to be key-value
pairs with following keys:

=over

=item alias

An array of aliases also accepted by F<Getopt::Long>.

=item callback

Call a subroutine every time the option changes (e.g. after pressing
on Apply, Ok or after loading). The callback will get a hash with the
following keys as argument:

=over

=item optdef

The opttable item definition for this option.

=item bag

A hash reference which is persistent for this L</process_options>
call. This can be used to share state between multiple callbacks.

=back

=item callback-interactive

Like C<callback>, but only applies in interactive mode.

=item label

A label to be displayed in the GUI instead of the option name.

=item help

A short help string used by B<usage> and the Balloon help facility in
B<option_editor>.

=item longhelp

A long help string used by B<option_editor>.

=item choices

An array of additional choices for the option editor.

If C<strict> is set to a true value, then the elements of choices may
also contain array references. In this case the first value of the
"sub" array references are the display labels and the second value
the used value. This is similar to L<Tk::Optionmenu> (in fact, for
displaying this option an Optionmenu is used).

     choices => ["one", "two", "three"]

     choices => [["english"  => "en"],
		 ["deutsch"  => "de"],
		 ["hrvatski" => "hr"]]


=item range

An array with the beginning and end of a range for an integer or float value.

=item strict

Must be used with B<choices> or B<range>. When set to true, options have to
match either the choices or the range.

=item subtype

Valid subtypes are I<file>, I<savefile>, I<dir>, I<geometry>, I<font>
and I<color>. These can be used with string options. For I<file> and
I<savefile>, the GUI interface will pop up a file dialog, using
L<getOpenFile|Tk::getOpenFile> for the former and
L<getSaveFile|Tk::getOpenFile/getSaveFile> for the latter. For I<dir>,
the GUI interface will pop up a dialog for selecting directories
(using either L<Tk::chooseDirectory>, L<Tk::DirSelect>, or a custom
dialog built on top of L<Tk::DirTree>). If the I<geometry> subtype is
specified, the user can set the current geometry of the main window.
The I<color> subtype is not yet implemented.

=item var

Use variable instead of I<$options-E<gt>{optname}> or I<$opt_optname>
to store the value.

=item nogui

This option will not have an entry in the GUI.

=item size

Create an entry with the specified size.

=item maxlength

Restrict the maximum number of characters in entries.

=item widget

This should be a reference to a subroutine for creating an own widget.
Folowing arguments will be passed to this subroutine: a reference to
the F<Tk::Getopt> object, Frame object, and the options entry. The
options entry should be used to get the variable reference with the
C<_varref> method. The subroutine should create a widget in the frame
(packing is not necessary!) and should return a reference to the
created widget.

A sample with an opttable entry for a custom numeric entry using the
CPAN module L<Tk::NumEntry>:

   ['numentry', '=i', 50,
    range => [0, 100],
    widget => sub { numentry_widget(@_) },
   ],

And C<numentry_widget> defined as:

    use Tk::NumEntry;
    sub numentry_widget {
        my($self, $frame, $opt) = @_;
        my $v = $self->varref($opt);
	$frame->NumEntry(-minvalue => $opt->[3]{range}[0],
    			 -maxvalue => $opt->[3]{range}[1],
			 -variable => $v,
    			 -value => $$v,
    		        );
    }

=back

Here is an example for using a complex opttable description:

    @opttable =
        ('Misc',   # Head of first group
	 ['debug', # name of the option (--debug)
          '!',     # type boolean, accept --nodebug
          0,       # default is 0 (false)
          callback => sub { $^W = 1
                                if $options->{'debug'}; }
          # additional attribute: callback to be called if
          # you set or change the value
          ],
         ['age',
          '=i',    # option accepts integer value
          18,
          strict => 1, # value must be in range
          range => [0, 100], # allowed range
          alias => ['year', 'years'] # possible aliases
          ],
	 'External', # Head of second group
         ['browser',
          '=s',    # option accepts string value
          'tkweb',
          choices => ['mosaic', 'netscape',
                      'lynx', 'chimera'],
          # choices for the list widget in the GUI
          label => 'WWW browser program'
          # label for the GUI instead of 'browser'
          ],
         ['foo',
          '=f',    # option accepts float value
          undef,   # no default value
          help => 'This is a short help',
          # help string for usage() and the help balloon
          longhelp => 'And this is a slightly longer help'
          # longer help displayed in the GUI's help window
          ]);

=head1 OPTION ENTRY METHODS

These methods operate on option entries:

=over

=item B<varref(>I<optentry>B<)>

Return the variable reference for this entry.

=item B<optextra(>I<optentry>, I<optarg>B<)>

Return the value for the specified I<optarg> argument. See the
L<OPTTABLE ARGUMENTS> section above for a list of possible arguments.

=back

=head1 COMPATIBILITY

The argument to -opttable can be converted to a C<Getopt::Long>
compatible argument list with the following function:

  sub opttable_to_getopt {
      my(%args) = @_;
      my $options = $args{-options};
      my @getopt;
      for (@{$args{-opttable}}) {
  	if (ref $_) {
  	    push @getopt, $_->[0].$_->[1];
  	    if (defined $_->[3] and ref $_->[3] ne 'HASH') {
  		my %h = splice @$_, 3;
  		$_->[3] = \%h;
  	    }
  	    if ($_->[3]{'var'}) {
  		push @getopt, $_->[3]{'var'};
  	    } else {
  		push @getopt, \$options->{$_->[0]};
  	    }
  	}
      }
      @getopt;
  }

=head1 REQUIREMENTS

You need at least:

=over 4

=item *

perl5.004 (perl5.003 near 5.004 may work too, e.g perl5.003_26)

=item *

Tk400.202 (better: Tk800.007) (only if you want the GUI)

=item *

Data-Dumper-2.07 (only if you want to save options and it's anyway
standard in perl5.005)

=back

=head1 BUGS

Be sure to pass a real hash reference (not a uninitialized reference)
to the -options switch in C<new Tk::Getopt>. Use either:

    my %options;
    my $opt = new Tk::Getopt(-options => \%options ...)

or

    my $options = {};
    my $opt = new Tk::Getopt(-options => $options ...)

Note the initial assignement for $options in the second example.

Not all of Getopt::Long is supported (array and hash options, <>, abbrevs).

The option editor probably should be a real widget.

The option editor window may grow very large if NoteBook is not used (should
use a scrollable pane).

If the user resizes the window, the buttons at bottom may disappear.
This is confusing and it is advisable to disallow the resizing:

    $opt_editor = $opt->option_editor;
    $opt_editor->resizable(0,0);

The API will not be stable until version 1.00.

This manual is confusing. In fact, the whole module is confusing.

Setting variables in the editor should not set immediately the real variables.
This should be done only by Apply and Ok buttons.

There's no -font option (you have to use tricks with the option db and
a special Name for the option editor):

    $top->optionAdd("*somename*font" => $font);
    $opt->option_editor(Name => "somename", ...);

There's no (easy) way to get a large option editor fit on small
screens. Try -font, if it would exist, but see above.

=head1 AUTHOR

Slaven Rezic <slaven@rezic.de>

This package is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<perl|perl>
L<Getopt::Long|Getopt::Long>
L<Data::Dumper|Data::Dumper>
L<Tk|Tk>
L<Tk::FileDialog|Tk::FileDialog>
L<Tk::NoteBook|Tk::NoteBook>
L<Tk::Tiler|Tk::Tiler>
L<Safe|Safe>

=cut
