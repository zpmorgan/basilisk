package basilisk::Rulemap;

use Mouse;
#use MooseX::Method::Signatures;

use basilisk::Rulemap::Rect;
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

#TODO: use these
has capture_hook => (
   is => 'ro',
   isa => 'CodeRef',
   default => sub{sub{}},
);
has placement_hook => (
   is => 'ro',
   isa => 'CodeRef',
   default => sub{sub{}},
);
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


#These must be implemented in a subclass
my $blah = 'use a subclass instead of basilisk::Rulemap';
sub move_is_valid{ die $blah}
sub evaluate_move{ die $blah}
sub node_to_string{ die $blah}
sub node_from_string{ die $blah}
sub node_liberties{ die $blah}
sub set_stone_at_node{ die $blah}
sub stone_at_node{ die $blah}
sub all_nodes{ die $blah}
sub copy_board{ die $blah}

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
   #Takes list of some dead stones. Other stones in same groups are also dead.
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
   return \@list;
}
sub mark_alive{
   my ($self, $board, $mask, $node) = @_;
   my ($alivenodes, $libs, $foes) = $self->get_chain ($board, $node);
   for my $n (@$alivenodes){
      delete $mask->{$self->node_to_string($n)};
   }
}

#this returns (terr_mask, [terr_points_b, terr_pts_w])
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

#TODO: moose's roles for different modes
sub score_mode{
   my $self = shift;
   my @phases = split ' ', $self->phase_description;
   my (%entities, %sides);
   for (@phases){
      /(\d)([wbr])/;
      $entities{$1}++;
      $sides{$2}++;
   }
   return 'ffa' if (@phases == keys %sides)
}

sub captures_of_side {die'do'}
sub captures_of_entity{
   my ($self, $entity, $captures) = @_;
   die 'wrong score mode' unless $self->score_mode eq 'ffa';
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
   die 'wrong score mode' unless $self->score_mode eq 'ffa';
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
sub detect_cycle_type{
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



1;
