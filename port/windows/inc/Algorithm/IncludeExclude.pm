package Algorithm::IncludeExclude;

use warnings;
use strict;
use Carp;

=head1 NAME

Algorithm::IncludeExclude - build and evaluate include/exclude lists

=head1 VERSION

Version 0.01_50

=cut

our $VERSION = '0.01_50';
$VERSION =~ s{_}{};

=head1 SYNOPSIS

Algorithm::IncludeExclude lets you define a tree of include / exclude
rules and then allows you to determine the best rule for a given path.

For example, to include everything, then exclude everything under
C<bar> or C<baz> but then include everything under C<foo baz>, you
could write:

   my $ie = Algorithm::IncludeExclude->new;
   
   # setup rules
   $ie->include();                      # default to include
   $ie->exclude('foo');
   $ie->exclude('bar');
   $ie->include(qw/foo baz/);

   # evaluate candidates
   $ie->evaluate(qw/foo bar/);          # exclude (due to 'foo' rule)
   $ie->evaluate(qw/bar baz/);          # exclude (due to 'bar' rule)
   $ie->evaluate(qw/quux foo bar/);     # include (due to '' rule)
   $ie->evaluate(qw/foo baz quux/);     # include (due to 'foo/baz' rule)

You can also match against regexes.  Let's imagine you want to exclude
everything in the C<admin> directory, as well as all files that end
with a C<.protected> extension.

Here's how to implement that:

   my $ie = Algorithm::IncludeExclude->new;
   $ie->exclude('admin');
   $ie->exclude(qr/[.]protected$/);

   $ie->evaluate(qw/admin let me in/);  # exclude (due to 'admin' rule)
   $ie->evaluate(qw/a path.protected/); # exclude (due to regex)
   $ie->evaluate(qw/foo bar/);          # undefined (no rule matches)

   $ie->include(qw/foo bar/);
   $ie->evaluate(qw/foo bar/);          # now it's included

If you wanted to include files inside the C<admin> path ending in C<.ok>,
you could just add this rule:

   $ie->include('admin', qr/[.]ok$/);
   $ie->evaluate(qw/admin super public records.ok/); # included

The most specific match always wins -- if there's not an exact match,
the nearest match is chosen instead.

=head1 NOTES

=over 4

=item *

Regexes can only appear as the last element in a rule:

   $ie->include(qr/foo/, qr/bar/);
   $ie->exclude(qr/foo/, qr/bar/);

If regexes were allowed anywhere, things could get very confusing,
very quickly.

=item *

Regexes are matched against any remaining path elements when they are
first encountered.  In the following example:

   $ie->include('foo', qr/bar/);
   $ie->evaluate('foo', 'baz', 'quux', 'bar'); # include

The match works like this.  First, 'foo' (from the include rule) and
'foo' (from the path being evaluated) are compared.  Since there's a
match, the next element in the path is examined against C<foo>'s
subtree.  The only remaining item in the rule tree is a regex, so the
regex is compared to the rest of the path being evaluated, joined by
the C<join> argument to new (see L</METHODS/new>); namely:

   baz/quux/bar

Since the regular expression matches this string, the include rule is
matched.

=item *

Regex rules are checked before non-regex rules.  For example:

  $ie->exclude('foo', 'bar');
  $ie->include(qr/bar/);

  $ie->evaluate('foo', 'bar'); # include, due to regex

=item *

If two or more regular expressions at the same level match a path, the
result is undefined:

  $ie->include(qr/foo/);
  $ie->exclude(qr/bar/);
 
  $ie->evaluate('foobar'); # undef is returned

=back

=cut

=head1 METHODS

=head2 new

Create a new instance.  Accepts an optional hashref of arguments.  The
arguments may be:

=over 4

=item join 

String to join remaining path elements with when matching against a
regex.  Defaults to C</>, which is good for matching against URLs or
filesystem paths.

=back

=cut

# self is a tree, that looks like:
# {path1 => [ value1, {path2 => [ value2, ... ]}]}
# path1 has value value1
# path1->path2 has value value2
# path3 is undefined
# etc

sub new {
    my $class = shift;
    my $args = shift || {};
    $args->{join} ||= ''; # avoid warnings
    $args->{regexes} = {};
    my $self = [undef, {}, $args];
    return bless $self => $class;
}

# walks down the tree and sets the value of path to value
sub _set {
    my $tree  = shift;
    my $path  = shift;
    my $value = shift;
    
    my $regexes = $tree->[2]->{regexes};

    my $ref = 0;
    foreach my $head (@$path){
	# ignore everything after a qr// rule
	croak "Ignoring values after a qr// rule" if $ref;
	if(ref $head){
	    $ref = 1;
	    $regexes->{"X$head"} = $head;
	    $head = "X$head";
	}
	else {
	    $head = "0$head";
	}
	my $node = $tree->[1]->{$head};
	$node = $tree->[1]->{$head} = [undef, {}]
	  if('ARRAY' ne ref $node);
	
	$tree = $node;
    }
    $tree->[0] = $value;
}

=head2 include(@path)

Add an include path to the rule tree.  C<@path> may end with a regex.

=cut

sub include {
    my $self = shift;
    my @path = @_;
    $self->_set(\@path, 1);
}

=head2 exclude(@path)

Add an exclude path to the rule tree.  C<@path> may end with a regex.

=cut

sub exclude {
    my $self = shift;
    my @path = @_;
    $self->_set(\@path, 0);
}

=head2 evaluate(@path)

Evaluate whether C<@path> should be included (true) or excluded
(false).  If the include/exclude status cannot be determined (no rules
match, more than one regex matches), C<undef> is returned.

=cut

sub evaluate {
    my $self = shift;
    my @path = @_;
    my $value = $self->[0];
    my $tree  = [@{$self}]; # unbless

    # "constants" (in here anyway)
    my %REGEXES = %{$self->[2]->{regexes}};
    my $JOIN = $self->[2]->{join};
    
    while(my $head = shift @path){
	# get regexes at this level;
	my @regexes = 
	  grep { defined }
	    map { $REGEXES{$_} } 
	      grep { /^X/ }
		keys %{$tree->[1]};
	
	if(@regexes){
	    my $matches = 0;
	    my $rest = join $JOIN, ($head,@path);
	    foreach my $regex (@regexes){
		if($rest =~ /$regex/){
		    $value = $tree->[1]->{"X$regex"}->[0];
		    $matches++;
		}
	    }
	    return undef if($matches > 1);
	    return $value if $matches == 1;
	}

	$tree = $tree->[1]->{"0$head"};
	last unless ref $tree;
	if (defined $tree->[0]) {
	    $value = $tree->[0];
	}
    }

    return $value;
}

=head1 AUTHOR

Jonathan Rockway, C<< <jrockway at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-algorithm-includeexclude at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Algorithm-IncludeExclude>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Algorithm::IncludeExclude

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Algorithm-IncludeExclude>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Algorithm-IncludeExclude>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Algorithm-IncludeExclude>

=item * Search CPAN

L<http://search.cpan.org/dist/Algorithm-IncludeExclude>

=back

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2007 Jonathan Rockway, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Algorithm::IncludeExclude
