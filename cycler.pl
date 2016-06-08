#!/usr/bin/env perl

use strict;
use warnings;

use Term::Screen;

my @fkeys = qw/kd kr/;
my @bkeys = qw/ku kl/;

my @list = qw/
one
two
sdfsdf
eee
345dfg
/;

##############

my %fkeys = map {$_=>1} @fkeys;
my %bkeys = map {$_=>1} @bkeys;

my $curNdx = 0;

my $scr = Term::Screen->new() or die "error";

&_upd_set_ndx();


while(my $char = $scr->getch) {

  if($fkeys{$char}) {
    &_upd_set_ndx($curNdx + 1);
  }
  elsif($bkeys{$char}) {
    &_upd_set_ndx($curNdx - 1);
  }
  else {
    &_upd_set_ndx();
  }
}



######################################


sub _upd_set_ndx {
  my $ndx = shift // $curNdx // 0;
  
  my $lastNdx = scalar(@list) - 1;
  $ndx = $lastNdx if ($ndx > $lastNdx);
  $ndx = 0 if ($ndx < 0);
  
  $curNdx = $ndx;
  
  $scr->clrscr();
  $scr->at(2,3);
  
  $scr->puts("Ref list:");
  
  my $startRow = 4;
  my $i = 0;
  for my $itm (@list) {
    if ($i == $curNdx) {
      $scr->at($startRow + $i,5)->bold->puts('*');
    }
    
    $scr->at($startRow + $i,7)->puts($itm);
  
    $scr->normal;
    $i++;
  }
  
  $scr->at($startRow + $i + 1,3);
  $scr->puts(scalar(@list) . ' refs (use arrow keys to change ref): ');
  
}

