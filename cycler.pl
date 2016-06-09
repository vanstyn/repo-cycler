#!/usr/bin/env perl

use strict;
use warnings;

use Term::Screen;
use Git::Wrapper;
use RapidApp::Util ':all';

my @fkeys = ('kd','kr',' ',"\r","\t");  # Down, Right, Space, Enter, Tab
my @bkeys = ('ku','kl',"\b");           # Up, Left, Backspace

##############

my ($prevNdx,$curNdx,$lowNdx,$highNdx) = (0,0,0,0);

my $git = Git::Wrapper->new($ARGV[0]);
my $scr = Term::Screen->new() or die "error";

my @tags = &_ordered_tags_from_ref();

my @list  = map { $_->{tag} } @tags;
my $extra = { map { $_->{tag} => $_ } @tags };

my $max_len = 0;
length($_) > $max_len and $max_len = length($_) for (@list);

my %fkeys = map {$_=>1} @fkeys;
my %bkeys = map {$_=>1} @bkeys;


&_upd_set_ndx();

while(1) {
  local $SIG{'WINCH'} = sub { &_upd_set_ndx() }; # term resize event
  
  my $char = $scr->getch; # blocks
  
  if($fkeys{$char}) {
    &_upd_set_ndx($curNdx + 1);
  }
  elsif($bkeys{$char}) {
    &_upd_set_ndx($curNdx - 1);
  }
  elsif(lc($char) eq 'q') {
    print "\r\n\n";
    exit;
  }
  else {
    &_upd_set_ndx();
  }
}




######################################


sub _upd_set_ndx {
  my $ndx = shift // $curNdx // 0;
  
  my $count = scalar(@list);
  
  my $lastNdx = $count - 1;
  $ndx = $lastNdx if ($ndx > $lastNdx);
  $ndx = 0 if ($ndx < 0);
  
  &_set_ndx($ndx);
  
  $scr->resize;
  $scr->clrscr();
  
  my @sublist = @list;
  
  my $maxLines = $scr->rows - 7;
  
  if($count > $maxLines) {
  
    if($highNdx - $lowNdx != $maxLines) {
      $highNdx = $maxLines - 1;
      $lowNdx = 0;
    }
  
    $highNdx ||= $lastNdx;
    
    if($ndx <= $lowNdx) {
      $lowNdx = $ndx - 1;
      $lowNdx = 0 if ($lowNdx < 0);
      $highNdx = $lowNdx + $maxLines;
      $highNdx = $lastNdx if ($highNdx > $lastNdx);
    }
    
    if($ndx >= $highNdx) {
      $highNdx = $ndx + 1;
      $highNdx = $lastNdx if ($highNdx > $lastNdx);
      
      $lowNdx = $highNdx - $maxLines;
      $lowNdx = 0 if ($lowNdx < 0);
    }
    
    @sublist = @list[$lowNdx..$highNdx];
  }
  

  $scr->at(1,3);
  $scr->puts("Date-ordered, unique tags:");
  
  $scr->puts("  lowNdx: $lowNdx  highNdx: $highNdx  curNdx: $curNdx  maxLines: $maxLines");
  
  my $startRow = 3;
  my $i = 0;
  for my $itm (@sublist) {
    my $info = $extra->{$itm} or die "Missing info for $itm";
  
    $scr->at($startRow + $i,1)->puts($info->{ndx});
  
    if ($info->{ndx} == $curNdx) {
      $scr->at($startRow + $i,5)->bold->puts('*');
    }
    
    $scr->at($startRow + $i,7)->puts($itm);
    
    my $spaces = $max_len - length($itm);
    $scr->puts(' ' x $spaces);
    $scr->puts("  $info->{subject}");
  
    $scr->normal;
    $i++;
  }
  
  $scr->at($startRow + $i + 1,3);
  $scr->puts("[Repo: $ARGV[0]]\r\n    -- $count refs (use arrow keys to change ref): ");
  
}


sub _set_ndx {
  my $ndx = shift;
  
  return if ($curNdx == $ndx);
  
  $prevNdx = $curNdx;
  $curNdx  = $ndx;
  
  
  # Do other stuff on change
  # ...
  


}

sub _last_move_forward {


}


sub _ordered_tags_from_ref {
  my $ref = shift || 'master';
  my $tags = &_tags_hash_from_ref($ref);
  my @list = sort { $a->{epoch} <=> $b->{epoch} } values %$tags;
  my $i = 0;
  $_->{ndx} = $i++ for @list;
  return @list;
}


sub _tags_hash_from_ref {
  my $ref = shift || 'master';
  
  my $commits = &_commit_hash_from_ref($ref);

  my $tags = {};
  my %seen_sha = ();
  
  for my $line ( $git->RUN("show-ref", '--tags') ) {
    my ($sha1,$ref_path) = split(/\s+/,$line,2);
    
    my $commit = $commits->{$sha1} or next;
    next if ($seen_sha{$sha1}++);

    my $tag = (reverse split(/\//,$ref_path))[0];
    
    $tags->{$tag} = {
      %$commit,
      tag   => $tag,
      sha1  => $sha1 
    };
  
  }
  
  return $tags;
}


sub _commit_hash_from_ref {
  my $ref = shift || 'master';
  
  my $commits = {};

  for my $line ( $git->RUN("log", '--format=%H::%ct::%s', $ref) ) {
    my ($sha1,$epoch,$subject) = split(/::/,$line,3);
    
    $commits->{$sha1} = {
      epoch   => $epoch,
      subject => $subject
    };
  }
  
  return $commits;
}

