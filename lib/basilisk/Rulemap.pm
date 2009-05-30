package basilisk::Rulemap;

use Moose;
#use MooseX::Method::Signatures;

use basilisk::Rulemap::Rect;
use basilisk::Rulemap::Heisengo;
use basilisk::Rulemap::Planckgo;
use basilisk::Util;
use List::MoreUtils qw/all/;

# This class evaluates moves and determines new board positions.
# This class stores no board/position data.
# Also, will must be used to determine visible portions of the board if there's fog of war.

# This class is basically here to define default behavior and
#   to provide a mechanism to override it.
# However this class will not handle rendering.

# Rulemaps are not stored in the database. They are derived from
#   entries in the Ruleset and Extra_rule tables.
# Some extra rules could be assigned using Moose's roles.
# Example: 'fog of war', 'atom go' each could be assigned to several variants.

# Also: This does not involve the ko rule. That requires a database search 
#   for a duplicate position.

# Note: I'm treating intersections (i.e. nodes) as scalars, which different rulemap 
#   subclasses may handle as they will. Rect nodes [$row,$col].


#To support more than 2 players or sides, each game inherently has a sort of basis
# such as 'ffa', 'zen', 'team', 'perverse', or perhaps more


has topology => (
   is => 'ro',
   isa => 'Str',
   default => 'plane'
);
has phase_description => (
   is => 'ro',
   isa => 'Str',
   default => '0b 1w'
);
has komi => (
   is => 'ro',
   isa => 'Num',
   default => '0'
);

# to be extended to fog, atom, etc
sub apply_rule_role{
   my ($self, $rule, $param) = @_;
   if ($rule =~ /^heisengo/){
      basilisk::Rulemap::Heisengo::apply ($self, $param);
   }
   elsif ($rule =~ /^planckgo/){
      basilisk::Rulemap::Planckgo::apply ($self, $param);
   }
   else {die $rule} 
}


#These must be implemented in a subclass
my $blah = 'use a subclass instead of basilisk::Rulemap';
sub move_is_valid{ die $blah}
sub node_to_string{ die $blah}
sub node_from_string{ die $blah}
sub node_liberties{ die $blah}
sub set_stone_at_node{ die $blah}
sub stone_at_node{ die $blah}
sub all_nodes{ die $blah}
sub copy_board{ die $blah}


sub evaluate_move{
   my ($self, $board, $node, $side) = @_;
   die "bad side $side" unless $side =~ /^[bwr]$/;
   
   if ($self->stone_at_node ($board, $node)){
      return (undef,"stone exists at ". $self->node_to_string($node)); }
   
   #produce copy of board for evaluation -> add stone at $node
   my $newboard = $self->copy_board ($board);
   $self->set_stone_at_node ($newboard, $node, $side);
   # $chain is a list of strongly connected stones,
   # and $foes=enemies,$libs=liberties adjacent to $chain
   my ($chain, $libs, $foes) = $self->get_chain($newboard, $node);
   my $caps = $self->find_captured ($newboard, $foes);
   if (@$libs == 0 and @$caps == 0){
      return (undef,'suicide');
   }
   for my $cap(@$caps){ # just erase captured stones
      $self->set_stone_at_node ($newboard, $cap, 0);
   }
   return ($newboard, '', $caps, $node);#no err
   #node is returned to make this method easier to override for heisenGo
}

#this is perfectly clear.
sub nodestrings_string_to_nodestrings_list{
   my ($self, $nodes) = @_; #'4-4_3-5', to ('4_4','3_5')
   my @nodestrings = split '_', $nodes;
   return @nodestrings
}
sub nodestrings_to_list{
   my ($self, $nodes) = @_; #'4-4_3-5', etc
   my @nodestrings = split '_', $nodes;
   return map {$self->node_from_string($_)} @nodestrings
}
sub nodestrings_from_list{
   my ($self, $nodes) = @_; #[[3,3],[5,4]] 
   my $nodestrings = join '_', map {$self->node_to_string($_)} @$nodes;
   return $nodestrings  #'4-4_3-5', etc
}

#uses a floodfill algorithm
#returns (string, liberties, adjacent_foes)
sub get_chain { #for all board types
   my ($self, $board, $node1) = @_; #start row/column
   
   my %seen; #indexed by stringified nodes
   my @found;
   my @libs; #liberties
   my @foes; #enemy stones adjacent to string
   my $string_side = $self->stone_at_node($board, $node1);
   return unless defined $string_side; #empty
   #0 has to mean empty, (b black, w white, ...)
   my @nodes = ($node1); #array of adjacent intersections to consider
   
   while (@nodes) {
      my $node = pop @nodes;
      next if $seen {$self->node_to_string ($node)};
      $seen {$self->node_to_string ($node)} = 1;
      
      my $here_side = $self->stone_at_node ($board, $node);
      
      unless ($here_side){ #empty
         push @libs, $node;
         next
      }
      if ($here_side eq $string_side){
         push @found, $node;
         push @nodes, $self->node_liberties ($node);
         next
      }
      # else enemy
      push @foes, $node;
   }
   return (\@found, \@libs, \@foes);
}


#chains are represented by a single 'delegate' node to identify chain
#returns chains, keyed by their delegates. a chain is a list of nodestrings
#also returns hash of {nodestring=>delegate} 
#also returns hash of {delegate=>side} 
sub all_chains{
   my ($self, $board) = @_;
   my %delegates;
   my %delegate_of_stone;
   my %delegate_side;
   for my $n ($self->all_stones($board)){
      my $s = $self->node_to_string($n);
      next if $delegate_of_stone{$s};
      
      $delegate_side{$s} = $self->stone_at_node($board, $n);
      my ($chain,$l,$f) = $self->get_chain($board, $n);
      #push @chains, $chain;
      #only deal with nodestrings here;
      $delegates{$s} =  [map {$self->node_to_string($_)} @$chain];
      my @nodestrings;
      #examine & to_string each node
      for (@$chain){
         my $nodestring =$self->node_to_string($_);
         push @nodestrings, $nodestring;
         $delegate_of_stone{$nodestring} = $s;
      }
   }
   return (\%delegates, \%delegate_of_stone, \%delegate_side)
}

sub all_stones {
   my ($self, $board) = @_;
   return grep {$self->stone_at_node($board, $_)} ($self->all_nodes);
}

#opposite of get_chain
sub get_empty_space{
   my ($self, $board, $node1, $ignore_stones) = @_; #start row/column
   return ([],[]) if $self->stone_at_node ($board, $node1);
   $ignore_stones = {} unless $ignore_stones; #dead stones tend to be ignored when calculating territory
   
   my %seen; #indexed by stringified nodes
   my @found;
   my @adjacent_stones;
   my @nodes = ($node1); #array of adjacent intersections to consider
   while (@nodes) {
      my $node = pop @nodes;
      my $nodestring = $self->node_to_string ($node);
      next if $seen {$nodestring};
      $seen {$nodestring} = 1;
      
      my $here_color = $self->stone_at_node ($board, $node);
      if (!$here_color or $ignore_stones->{$nodestring}){ #empty
         push @found, $node;
         push @nodes, $self->node_liberties ($node)
      }
      else{ #stone
         push @adjacent_stones, $node;
      }
   }
   return (\@found, \@adjacent_stones);
}


#take a list of stones, returns those which have no libs, as chains
sub find_captured{
   my ($self, $board, $nodes) = @_;
   my @nodes = @$nodes; #list
   my %seen; #indexed by stringified node
   my @caps; #list
   while (@nodes){
      my $node = pop @nodes;
      next if $seen {$self->node_to_string($node)};
      my ($chain, $libs, $foes) = $self->get_chain ($board, $node);
      my $capture_these = scalar @$libs ? '0' : '1';
      for my $n (@$chain){
         $seen {$self->node_to_string($n)} = 1;
         push @caps, $n if $capture_these;
      }
   }
   return \@caps
}

# A death_mask is basically a set of stringified nodes with an entry 
#   where there's a dead string. Only one stone per string need be marked.
# This stuff is just for scoring. Maybe it could be used for 
#   some interactive score estimation too.

sub death_mask_from_list{ 
   #Takes list of some dead stones. Other stones in same chains are also dead.
   my ($self, $board, $list) = @_;
   my %mask;
   for my $node (@$list){
      my ($deadchain, $libs, $foes) = $self->get_chain ($board, $node);
      for my $deadnode (@$deadchain){
         $mask {$self->node_to_string($deadnode)} = 1;
      }
   }
   return \%mask;
}
sub death_mask_to_list{
   #turns each dead string into a representative stringified node
   my ($self, $board, $mask) = @_;
   my @list;
   my %seen;
   for my $node ($self->all_nodes){
      my $nodestring = $self->node_to_string($node);
      if ($mask->{$nodestring}) { #marked dead
         next if $seen {$nodestring};
         my ($deadnodes, $libs, $foes) = $self->get_chain ($board, $node);
         die 'blah?' unless @$deadnodes;
         for my $deadnode (@$deadnodes){
            $seen {$self->node_to_string($deadnode)} = 1;
         }
         push @list, $deadnodes->[0];
      }
   }
   return @list;
}
sub mark_alive{
   my ($self, $board, $mask, $node) = @_;
   my ($alivenodes, $libs, $foes) = $self->get_chain ($board, $node);
   for my $n (@$alivenodes){
      delete $mask->{$self->node_to_string($n)};
   }
}

#this returns (terr_mask, {side=>points})
sub find_territory_mask{
   my ($self, $board, $death_mask) = @_;
   $death_mask ||= {};
   my %seen; #accounts for all empty nodes.
   my %terr_mask;
   my %terr_points;# {b,w,r}
   $terr_points{$_}=0 for $self->all_sides;
   
   for my $node ($self->all_nodes){
      next if $seen{$self->node_to_string($node)};
      my ($empties, $others) = $self->get_empty_space($board, $node, $death_mask);
      next unless @$empties and @$others;
      
      my $terr_side = $self->stone_at_node ($board, $others->[0]);
      my $is_terr = 1; #true, if this space is someone's territory
      for my $stone (@$others){
         next if $death_mask->{$self->node_to_string($stone)};
         $is_terr = 0 unless $self->stone_at_node ($board, $stone) eq $terr_side;
      }
      for my $e (@$empties){
         $seen{$self->node_to_string($e)} = 1;
         if ($is_terr){
            $terr_mask{$self->node_to_string($e)} = $terr_side;
            $terr_points{$terr_side}++;
         }
      }
   }
   return (\%terr_mask, \%terr_points);
}

sub count_deads{
   my ($self, $board, $death_mask) = @_;
   my %deads; #{b,w,r}
   for ($self->all_sides){
      $deads{$_} = 0;
   }
   for my $deadnodestring (keys %$death_mask){
      my $node = $self->node_from_string ($deadnodestring);
      my $side = $self->stone_at_node ($board, $node);
      $deads{$side}++;
   }
   return \%deads;
}

sub compare_masks{
   my ($self, $mask1, $mask2) = @_;
   return 0 unless (keys %$mask1 == keys %$mask2);
   for my $n (keys %$mask1){
      return 0 unless $mask2->{$n};
   }
   return 1;
}

sub captures_of_side {die'do'}
sub captures_of_entity{
   my ($self, $entity, $captures) = @_;
   die 'wrong score mode' unless $self->detect_basis eq 'ffa';
   unless (defined $captures) {$captures = $self->default_captures}
   my @caps = split ' ', $captures;
   for my $phase (split ' ', $self->phase_description) {
      if ($phase =~ m/$entity/){
         return shift @caps
      }
      else {
         shift @caps
      }
   }
}
sub side_of_entity{
   my ($self, $entity) = @_;
   die 'wrong score mode' unless $self->detect_basis eq 'ffa';
   for my $phase (split ' ', $self->phase_description) {
      if ($phase =~ m/$entity([wbr])/){
         return $1;
      }
   }
}
sub all_entities{
   my $self = shift;
   my $pd = $self->phase_description;
   my %e;
   while($pd=~/(\d)/g){
      $e{$1}=1
   }
   return keys %e;
}
sub all_sides{
   my $self = shift;
   my $pd = $self->phase_description;
   my %s;
   while($pd=~/([bwr])/g){
      $s{$1}=1
   }
   return keys %s;
}

sub default_captures {#for before move 1
   my $self = shift;
   my @phases = split ' ', $self->phase_description;
   return join ' ', map {0} (1..@phases) #'0 0'
}


#Necessary to decide how to describe game in /game. 
#Score & game objectives depend.
#reads the phase description and
# returns 'ffa', 'team', 'zen', or 'perverse'? or 'other'?
sub detect_basis{
   my $self = shift; #is it a pd or a rulemap?
   my $pd = ref $self ? $self->phase_description : $self;
   
   #assume that this is well-formed
   #and no entity numbers are skipped
   my @phases = map {[split'',$_]} split ' ', $pd;
   my %ents;
   my %sides;
   for (@phases){
      $ents{$_->[0]}{$_->[1]} = 1;
      $sides{$_->[1]}{$_->[0]} = 1;
   }
   return 'ffa' if @phases == keys %ents
               and @phases == keys %sides;
   return 'zen' if all {keys %{$ents{$_}} == keys%sides} (keys%ents); 
   
   return 'other';
}

sub compute_score{
   my ($self, $board, $caps, $death_mask) = @_;
   my ($terr_mask, $terr_points) = $self->find_territory_mask($board, $death_mask);
   
   my $type = $self->detect_basis;
   my $pd = $self->phase_description;
   my @phases = split ' ', $pd;
   @phases = map {[split '', $_]} @phases;
   
   my @sides = $self->all_sides;
   my %side_score =  map {$_=>0} @sides;
   
   { #add up captures of each team.
      my @caps = split ' ', $caps; # from latest move
      for my $phase (@phases){
         my $phase_caps = shift @caps;
         $side_score{$phase->[1]} += $phase_caps;
      }
      #add up territory of each team.
      for my $side (@sides){
         $side_score{$side} += $terr_points->{$side};
      }
      #and count dead things in death_mask 
      #points in death_mask go to territory owner in terr_mask
      for my $d (keys %$death_mask){
         my $capturer = $terr_mask->{$d};
         if ($capturer){
            $side_score{$capturer}++;
         }
      }
   }
   
   if ($self->phase_description eq '0b 1w'){
      $side_score{w} += $self->komi;
   }
   
   if ($type eq 'ffa' or $type eq 'zen' or $type eq 'team'){
      return \%side_score
   }
   return  'perverse or other modes not scoring...'
}

sub num_phases{
   my ($self) = @_;
   my @phases = split ' ', $self->phase_description;
   return scalar @phases;
}

sub determine_next_phase{
   my ($self, $phase, $choice_phases) = @_;
   my $np = $self->num_phases;
   my $next = $phase;
   for (1..$np){
      $next = ($next + 1) % $np;
      return $next if grep {$next==$_} @$choice_phases;
   }
   die "I was given a bad list of choice phases: " . join',',@$choice_phases;
}

#compare initial board to a blank slate.
#this delta fits nicely in position 0 for 
# a delta list that covers the game.
sub initial_delta{
   my ($self, $initial_board) = @_;;
   return {} unless $initial_board;
   
   my %delta;
   for my $node ($self->all_nodes){
      if (my $c = $self->stone_at_node($initial_board, $node)){
         my $nstr = $self->node_to_string($node);
         $delta{$nstr} = ['add', {stone => $c}];
      }
   }
   return \%delta;
}


#compare initial earlier board to later board.
sub delta{
   my ($self, $board1, $board2) = @_;
   
   my %delta;
   for my $node ($self->all_nodes){
      my $fore = $self->stone_at_node($board1, $node); #0,w,b,etc
      my $afte = $self->stone_at_node($board2, $node);
      if ($fore ne $afte){
         my $n = $self->node_to_string($node);
         if (!$afte){
            $delta{$n} = ['remove', {stone => $fore}];
         }
         elsif (!$fore){
            $delta{$n} = ['add', {stone => $afte}];
         }
         else{
            $delta{$n} = ['update', {stone => $fore}, {stone => $afte}];
         }
      }
   }
   return \%delta;
}
1;
