#!/usr/bin/env perl

use strict;
use warnings;

use Term::Screen;
use Git::Wrapper;
use Path::Class qw/file dir/;

use RapidApp::Util ':all';

my @fkeys = ('kd','kr',' ',"\r","\t");  # Down, Right, Space, Enter, Tab
my @bkeys = ('ku','kl',"\b");           # Up, Left, Backspace

##############

# globals:
my (
  $repo_path, $branch, $git, $scr,
  $prevNdx,$curNdx,$lowNdx,$highNdx,
  @list, $max_len, $extra, %fkeys, %bkeys,
  $initialized
);

&_init();

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
  
  $scr->flush_input; # prevent key strokes from queueing up
}

END {
  if($initialized) {
    print "\r\n\ncleaning up...\r\n";
    &_set_git_ref($branch);
  }
}



######################################


sub _init {

  $repo_path = dir($ARGV[0])->resolve->absolute->stringify;
  die "Not a directory" unless (-d $repo_path);

  ($prevNdx,$curNdx,$lowNdx,$highNdx) = (0,0,0,0);

  $git = &_init_git_wrapper($repo_path);
  $scr = Term::Screen->new() or die "error";
  
  my @tags = &_ordered_tags_from_ref($branch);

  @list  = map { $_->{tag} } @tags;
  $extra = { map { $_->{tag} => $_ } @tags };

  $max_len = 0;
  length($_) > $max_len and $max_len = length($_) for (@list);

  %fkeys = map {$_=>1} @fkeys;
  %bkeys = map {$_=>1} @bkeys;

  # Make Ctrl-C, etc sigs call normal exit so END blocks are called
  $SIG{$_} = sub { exit; } for (qw/INT TERM HUP QUIT ABRT/);

  $initialized = 1;
}

sub _init_git_wrapper {
  my $repo_path = shift;
  
  my $Git = Git::Wrapper->new($repo_path);
  
  my $Statuses = $Git->status;
  
  if ($Statuses->is_dirty) {
    my @msgs = ();
    for my $group (qw/indexed changed unknown conflict/) {
      my @status = $Statuses->get($group);
      my $cnt = scalar(@status) or next;
      push @msgs, "$cnt items in '$group'";
    }
    die join('',
      "Target repo is_dirty -- ",join(', ',@msgs),
      "\n aborting...\n"
    );
  }
  
  ($branch) = $Git->RUN(qw/rev-parse --abbrev-ref HEAD/);
  die "Target repo not currently on any branch\n" if ($branch eq 'HEAD');

  
  return $Git
}



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
  
  $scr->at(0,35)->puts("lowNdx: $lowNdx  highNdx: $highNdx  curNdx: $curNdx  maxLines: $maxLines");
  
  $scr->at(1,3)->puts("Date-ordered, unique tags:");
  
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
  $scr->puts("[Repo: $repo_path]\r\n    -- $count refs (use arrow keys to change ref): ");
  
}


sub _set_ndx {
  my $ndx = shift;
  
  return if ($curNdx == $ndx);
  
  $prevNdx = $curNdx;
  $curNdx  = $ndx;
  
  &_set_git_ref($list[$ndx]);
  
}

sub _set_git_ref {
  my $ref = shift;
  
  if ($git->status->is_dirty) {
    $git->RUN(qw/reset --hard HEAD/);
  };
  
  $git->RUN('checkout',$ref);
  $git->RUN(qw/clean -d -f/);
  $git->RUN(qw/reset --hard HEAD/);
  
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

