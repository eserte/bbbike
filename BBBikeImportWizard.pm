# -*- perl -*-

#
# $Id: BBBikeImportWizard.pm,v 1.1 2004/03/23 23:52:52 eserte Exp eserte $
# Author: Slaven Rezic
#
# Copyright (C) 2004 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: slaven@rezic.de
# WWW:  http://www.rezic.de/eserte/
#

package BBBikeImportWizard;

=head1 NAME

BBBikeImportWizard - a colletion of "wizards" for BBBike

=head1 SYNOPSIS

   perl -MTk -MBBBikeImportWizard -e 'BBBikeImportWizard::create_import_wizard(tkinit,"file.csv");'

=cut

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.1 $ =~ /(\d+)\.(\d+)/);

use File::Basename qw(basename);
use List::Util qw(min);

use Text::CSV_XS;

use Tk::Wizard;
use Tk::LabFrame;
use Tk::NumEntry;
use Tk::ROText;
use Tk::BrowseEntry;

# XXX use Msg, auch fuer %Tk::Widget::LABELS

sub create_import_wizard {
    my($top, $file) = @_;
    if (!defined $file) {
	$file = $top->getOpenFile; # XXX more opts
	return if !defined $file;
    }

    my @data;
    open(F, $file) or main::status_message("Kann Datei $file nicht öffnen", "die");
    while(<F>) {
	chomp;
	push @data, $_;
    }
    close F;

    my $wizard = Tk::Wizard->new
	(-title => "BBBike data import",
	 #-imagepath      => "/image/for/the/left/panel.gif",
        );

    for ($wizard->{d}) {
	$_->{file}     = $file;
	$_->{data}     = \@data;
	$_->{datatype} = "sep";
	$_->{fromline} = 1;
	$_->{toline}   = scalar @data;
	$_->{sep}      = ";";
	$_->{textind}  = "\"";
    }

    # XXX should the addPage callbacks supply the $wizard parameter?
    $wizard->addPage(sub { datatype_page($wizard) });
    $wizard->addPage(sub { separator_page($wizard) });
    $wizard->addPage(sub { column_page($wizard) });
    $wizard->Show; # XXX Show should act like Dialog::Show (blocking)
    MainLoop; # XXX remove this
    $wizard->do_import;
}

sub datatype_page {
    my $wizard = shift;
    my $d = $wizard->{d};
    my $f = $wizard->blank_frame
	(-title => "Datentype und Anzahl der Zeilen",
	);
    # XXX document that Frame contents should be packed
    my $f0 = $f->Frame->pack(-fill => "both", -expand => 1);
    Tk::grid($f0->Label(-text => "Die Struktur der Daten festelegen"),
	     -sticky => "ew");
    {
	my $ff;
	Tk::grid($ff = $f0->LabFrame(-label => "Ausgabeoptionen",
				     -labelside => "acrosstop"),
		 -sticky => "ew");

	{
	    my $fff;
	    Tk::grid($ff->Label(-text => "Ursprünglicher Datentyp:"),
		     $fff = $ff->Frame,
		     -sticky => "w");
	    Tk::grid($fff->Radiobutton(-text => "Abgetrennt",
				       -value => 'sep',
				       -variable => \$d->{datatype}),
		     $fff->Radiobutton(-text => "Feste Breite",
				       -value => 'fixed',
				       -variable => \$d->{datatype}),
		     -sticky => "w");
	    Tk::grid($ff->Label(-text => "Beschneiden:"),
		     $ff->Optionmenu(-options =>
				     [["Immer (beide Seiten)" => 0],
				      ["Nie" => 1],
				      ["Nur auf der linken Seite" => 2],
				      ["Nur auf der rechten Seite" => 3]],
				     -variable => \$d->{trim}),
		     -sticky => "w");
	}
    }

    my $txt;

    {
	my($fromw, $tow);
	my $importtext;
	my $adjust_importtext = sub {
	    my $rows = ($d->{toline} - $d->{fromline} + 1);
	    $importtext = "$rows Zeile" . ($rows == 1 ? " ist" : "n sind") . " zu importieren";
	};
	my $adjust = sub {
	    my $w = shift;
	    if ($w eq $fromw) {
		$tow->configure(-minvalue => $d->{fromline});
	    } else {
		$fromw->configure(-maxvalue => $d->{toline});
	    }
	    $txt->tagRemove("hide", "1.0", "end");
	    $txt->tagAdd("hide", "1.0", $d->{fromline}.".0")
		if $d->{fromline} > 1;
	    $txt->tagAdd("hide", ($d->{toline}+1).".0", "end")
		if $d->{toline} < scalar @{$d->{data}};
	    $adjust_importtext->();
	};
	my $ff;
	Tk::grid($ff = $f0->LabFrame(-label => "Zu importierende Zeilen",
				     -labelside => "acrosstop"),
		 -sticky => "ew");
	Tk::grid($ff->Label(-text => "Von Zeile:"),
		 $fromw = $ff->NumEntry
		 (-minvalue => 1,
		  -maxvalue => scalar @{ $d->{data} },
		  -textvariable => \$d->{fromline},
		  -browsecmd => sub { $adjust->($fromw) },
		  -width => 6,
		 ),
		 $ff->Label(-text => "Bis Zeile:"),
		 $tow = $ff->NumEntry
		 (-minvalue => 1,
		  -maxvalue => scalar @{ $d->{data} },
		  -textvariable => \$d->{toline},
		  -browsecmd => sub { $adjust->($tow) },
		  -width => 6,
		 ),
		 #XXX -sticky => "w",
		 $ff->Label(-textvariable => \$importtext),
		 -sticky => "e",
		),
;
	$adjust_importtext->();
    }

    {
	my $ff;
	Tk::grid($ff = $f0->LabFrame(-label => "Daten (von " . basename($d->{file}) . ")",
				     -labelside => "acrosstop"),
		 -sticky => "ew");
	Tk::grid($txt = $ff->Scrolled("ROText", -scrollbars => "osoe",
				      -border => 0, -highlightthickness => 0),
		 -sticky => "ew");
	$txt->insert("end", "$_\n") for @{ $d->{data} };
	$txt->tagConfigure("hide", -elide => 1);
    }

    $f;
}

sub separator_page {
    my $wizard = shift;
    my $d = $wizard->{d};
    my $f = $wizard->blank_frame
	(-title => "Anpassung der Trennzeichen",
	);
    my $f0 = $f->Frame->pack(-fill => "both", -expand => 1);
    Tk::grid($f0->Label(-text => "Die Trennzeichen wählen, die im Text vorkommen. Sie können\nmehrere Trennzeichen wählen, wenn erforderlich, und Sie können ein eigenes\nTrennzeichen angeben."),
	     -sticky => "ew");

    my $listf;

    my $chng = sub {
	if ($listf->Subwidget("Table")) {
	    $listf->Subwidget("Table")->destroy;
	}
	my $csv = Text::CSV_XS->new({ quote_char => $d->{textind},
				      sep_char   => $d->{sep},
				      binary     => 1,
				    });
	# Check first lines for column number
	my $check_toline = min($d->{toline}-1, $d->{fromline}-1+10);
	my $columns = 1;
	for my $line (@{$d->{data}}[$d->{fromline}-1 .. $check_toline]) {
	    if ($csv->parse($line)) {
		my $no_columns = scalar $csv->fields;
		$columns = $no_columns if ($no_columns > $columns);
	    }
	}
	$d->{columns} = $columns;

	my $list = $listf->Scrolled("HList",
				    -scrollbars => "osoe",
				    -header => 1,
				    -columns => $columns,
				    -width => 50, # XXX why?
				   )->grid(-sticky => "news");
	$listf->Advertise(Table => $list);
	for my $col (0 .. $columns-1) {
	    $list->headerCreate($col, -text => "Spalte " . ($col+1));
	}

	my $l = 0;
	for my $line (@{$d->{data}}[$d->{fromline}-1 .. $d->{toline}-1]) {
	    if ($csv->parse($line)) {
		my @columns = $csv->fields;
		if (@columns > $columns) {
		    splice @columns, $columns;
		}
		$list->add($l, -text => $columns[0]);
		for my $col (1 .. $#columns) {
		    $list->itemCreate($l, $col, -text => $columns[$col]);
		}
		$l++;
	    }
	}
    };

    {
	my($ff1, $ff2);
	Tk::grid($ff1 = $f0->LabFrame(-label => "Trennzeichen",
				      -labelside => "acrosstop"),
		 $ff2 = $f0->LabFrame(-label => "Sonstiges",
				      -labelside => "acrosstop"),
		 -sticky => "news");

	Tk::grid($ff1->Radiobutton(-text => "Leerzeichen",
				   -command => $chng,
				   -value => " ",
				   -variable => \$d->{sep}),
		 $ff1->Radiobutton(-text => "Tabulator",
				   -command => $chng,
				   -value => "\t",
				   -variable => \$d->{sep}),
		 $ff1->Radiobutton(-text => "Ausrufezeichen (!)",
				   -command => $chng,
				   -value => "!",
				   -variable => \$d->{sep}),
		 -sticky => "w",
		);
	Tk::grid($ff1->Radiobutton(-text => "Doppelpunkt (:)",
				   -command => $chng,
				   -value => ":",
				   -variable => \$d->{sep}),
		 $ff1->Radiobutton(-text => "Komma",
				   -command => $chng,
				   -value => ",",
				   -variable => \$d->{sep}),
		 $ff1->Radiobutton(-text => "Trennstrich (-)",
				   -command => $chng,
				   -value => "-",
				   -variable => \$d->{sep}),
		 -sticky => "w",
		);
	Tk::grid($ff1->Radiobutton(-text => "Pipe (|)",
				   -command => $chng,
				   -value => "|",
				   -variable => \$d->{sep}),
		 $ff1->Radiobutton(-text => "Semikolon (;)",
				   -command => $chng,
				   -value => ";",
				   -variable => \$d->{sep}),
		 $ff1->Radiobutton(-text => "Schrägstrich (/)",
				   -command => $chng,
				   -value => "/",
				   -variable => \$d->{sep}),
		 -sticky => "w",
		);
	Tk::grid($ff1->Radiobutton(-text => "Benutzerdefiniert",
				   -command => $chng,
				   -value => "",
				   -variable => \$d->{sep}),
		 $ff1->Entry(-textvariable => \$d->{userdef_sep},
			     -validate => "all",
			     -vcmd => sub {
				 my $newval = shift;
				 if (length $newval <= 1) {
				     $f->afterIdle($chng);
				     1;
				 } else {
				     0;
				 }
			     }),
		 -sticky => "w",
		);

	Tk::grid($ff2->Checkbutton(-text => "Zwei Trennzeichen als eines sehen",
				   -variable => \$d->{doublesep}),
		 -sticky => "w");
	Tk::grid($ff2->Checkbutton(-text => "Aufeinander folgende Text-Indikatoren escapen",
				   -variable => \$d->{esctextind}),
		 -sticky => "w");#XXX name
	Tk::grid(my $textind_be = $ff2->BrowseEntry
		 (-label => "Text-Indikator:",
		  -textvariable => \$d->{textind},
		  -autolimitheight => 1,
		 ),
		 -sticky => "w"
		);
	$textind_be->insert("end", "\"", "\'", "\`"); # XXX check with gnumeric
    }

    {
	my $ff;
	Tk::grid($ff = $f0->LabFrame(-label => "Beispiel",
				     -labelside => "acrosstop"),
		 -sticky => "news");
	Tk::grid($listf = $ff->Frame,
		 -sticky => "news");
    }

    $chng->();

    $f;
}

sub column_page {
    my $wizard = shift;
    my $d = $wizard->{d};
    my $f = $wizard->blank_frame
	(-title => "Spaltenformatierung",
	);
    my $f0 = $f->Frame->pack(-fill => "both", -expand => 1);
    Tk::grid($f0->Label(-text => "Das Format für jede Spalte wählen. Sie können auf die Spaltenliste links klicken, um eine Spalte auszuwählen. Dann können Sie ein Format aus der Liste rechts wählen."),
	     -sticky => "ew");

    {
	my $ff;
	Tk::grid($ff = $f0->LabFrame(-label => "Je Spalte formatieren",
				     -labelside => "acrosstop"),
		 -sticky => "news");
	Tk::grid((my $colhl = $ff->Scrolled("HList", -scrollbars => "osoe",
					    -header => 1, -columns => 2)),
		 (my $fmtlb = $ff->Scrolled("Listbox", -scrollbars => "osoe")),
		 -sticky => "news");
	$colhl->headerCreate(0, -text => "Column");
	$colhl->headerCreate(1, -text => "Format");
	for my $col (0 .. $d->{columns}) {
	    $colhl->add($col, -text => 0);
	    $colhl->itemCreate($col, 1, -text => "<unbenutzt>");
	}
	$colhl->selectionSet(1);
	$fmtlb->insert("end", "Lat/Long", "Long/Lat", "Lat", "Long", "Label", "Category", "<unbenutzt>");
	$fmtlb->bind("<1>" => sub {
			 my($sel) = $colhl->infoSelection;
			 my($current) = $fmtlb->get($fmtlb->curselection);
			 $colhl->itemConfigure($sel, 1, -text => $current);
		     });
    }

    $f;
}

1;

__END__
