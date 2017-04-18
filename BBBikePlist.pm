# -*- perl -*-

#
# Author: Slaven Rezic
#
# Copyright (C) 2017 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikePlist;

use strict;
use vars qw($VERSION);
$VERSION = '0.01';

use XML::LibXML;

sub load_plist {
    my($class, %opts) = @_;
    my $doc = XML::LibXML->load_xml(%opts);
    my($plist_root) = $doc->documentElement->findnodes('/plist/*');
    $class->parse_node($plist_root);
}

sub parse_node {
    my($self, $node) = @_;
    if ($node->nodeName eq 'dict') {
	my %ret;
	my @childnodes = $node->findnodes('*');
	for(my $i=0; $i<$#childnodes; $i+=2) {
	    my $key = $childnodes[$i]->textContent;
	    my $val = $self->parse_node($childnodes[$i+1]);
	    $ret{$key} = $val;
	}
	\%ret;
    } elsif ($node->nodeName eq 'array') {
	my @ret;
	for my $childnode ($node->findnodes('*')) {
	    push @ret, $self->parse_node($childnode);
	}
	\@ret;
    } elsif ($node->nodeName eq 'false') {
	0;
    } elsif ($node->nodeName eq 'true') {
	1;
    } elsif ($node->nodeName =~ m{^(string|integer|real)$}) {
	$node->textContent;
    } else {
	die "No support for " . $node->nodeName;
    }
}

return 1 if caller;

my $file = shift;
my %opts = (defined $file ? (location => $file) : (IO => \*STDIN));
my $data = BBBikePlist->load_plist(%opts);
require Data::Dumper;
print Data::Dumper->new([$data],[qw()])->Indent(1)->Useqq(1)->Sortkeys(1)->Terse(1)->Dump;

__END__

=head1 NAME

BBBikePlist - simple (Mac) proplist parser

=head1 SYNOPSIS

Use as a module:

   my $data = BBBikePlist->load_plist(location => "/path/to/file.plist");

   my $data = BBBikePlist->load_plist(IO => \*STDIN);

Use as a script (dumps as perl data structure using L<Data::Dumper>):

   perl BBBikePlist.pm /path/to/file.plist

   cat /path/to/file.plist | perl BBBikePlist.pm

=cut
