# -*- perl -*-

package BBBikeChooseOrtWidgetTest;

use strict;
use vars qw($VERSION);
$VERSION = 1.00;

use Time::HiRes ();
use Test::More qw(no_plan);

sub start_guitest {
    my $end_time = Time::HiRes::time();
    diag "Starting choose_ort addwidget GUI test...\n";

    my $top = $main::top;
    my $c   = $main::c;

    # 1. Test choose_ort with -addwidgetcb
    my $t1 = main::choose_ort('p', 'o',
                             -addwidgetcb => sub {
                                 my ($lb, $ort, $ort_idx) = @_;
                                 return $lb->Button(-text => "MyBtn-$ort");
                             },
                             -popup => 0,
                            );

    ok(defined $t1, "choose_ort with -addwidgetcb returned a window");
    my $lb1 = $t1->Subwidget("Listbox");
    ok(defined $lb1, "Found HList widget in returned window");

    my @children1 = $lb1->info('children');
    cmp_ok(scalar(@children1), ">", 0, "HList contains entries");

    my $first_item1 = $children1[0];
    my $widget1 = $lb1->itemCget($first_item1, 1, '-window');
    ok(defined $widget1, "Widget at column 1 is defined for -addwidgetcb");
    isa_ok($widget1, 'Tk::Button', "Widget at column 1 is a Tk::Button");

    my $text1 = $lb1->itemCget($first_item1, 0, '-text');
    is($widget1->cget('-text'), "MyBtn-$text1", "Button text matches generated text");

    # 2. Test choose_ort with -splitter returning Hashrefs with cb
    my $t2 = main::choose_ort('p', 'o',
                              -splitter => sub {
                                  my ($ort, $ort_idx) = @_;
                                  return ($ort, { text => "Btn-$ort", cb => sub {
                                      my ($lb, $col_val) = @_;
                                      return $lb->Button(-text => $col_val->{text});
                                  }});
                              },
                              -popup => 0,
                              -rebuild => 1,
                             );

    ok(defined $t2, "choose_ort with splitter returned a window");
    my $lb2 = $t2->Subwidget("Listbox");
    ok(defined $lb2, "Found HList widget in splitter window");

    my @children2 = $lb2->info('children');
    cmp_ok(scalar(@children2), ">", 0, "Splitter HList contains entries");

    my $first_item2 = $children2[0];
    my $widget2 = $lb2->itemCget($first_item2, 1, '-window');
    ok(defined $widget2, "Widget at column 1 is defined for splitter Hashref");
    isa_ok($widget2, 'Tk::Button', "Widget at column 1 is a Tk::Button");

    my $text2 = $lb2->itemCget($first_item2, 0, '-text');
    is($widget2->cget('-text'), "Btn-$text2", "Splitter Button text matches generated text");

    # Clean up and exit
    $t1->destroy if Tk::Exists($t1);
    $t2->destroy if Tk::Exists($t2);

    diag "All tests passed successfully! Exiting...\n";
    main::exit_app_noninteractive();
}

1;
