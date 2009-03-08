package basilisk::Rulemap;

use Moose;
#use MooseX::Method::Signatures;

use basilisk::Rulemap::Rect;
use basilisk::Util;


# This class evaluates moves and determines new board positions.
# This class stores no board/position data.
# Also, will must be used to determine visible portions of the board if there's fog of war.

# Rulemaps are not stored in the database. They are derived from
#   entries in the Ruleset and Extra_rule tables.
# This is also where parameters relevant to specific rulesets are stored.
#   Example: 'size' might be meaningless for some boards.
#   Example: 'visibility' with fog of war.
#   Example: 'collisions' with fog of war.
# For a ruleset with an arbitrary graph, the whole graph is to be in rulemap. 
#   Not the position though

# This class is basically here to define default behavior and
#   to provide a mechanism to override it.
# However this class will not handle rendering.

# Also: This does not involve the ko rule. That requires a database search 
#   for a duplicate position.

# Note: I'm treating intersections (i.e. nodes) as scalars, which different rulemap 
#   subclasses may handle as they will. Nodes by default are [$row,$col].

#TODO: shifting turns&teams&colors in new ways (rengo,zen,consensus?)
# also: sides(1 and 2) shouldn't be tied to colors(1 and 2)

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

#These must be implemented in a subclass
my $blah = 'use a subclass instead of basilisk::Rulemap';
sub move_is_valid{ die $blah;}
sub evaluate_move{ die $blah;}
sub node_to_string{ die $blah;}
sub node_from_string{ die $blah;}
sub node_liberties{ die $blah;}
sub stone_at_node{ die $blah;}
sub all_nodes{ die $blah;}


#uses a floodfill algorithm
#returns (string, liberties, adjacent_foes)
sub get_chain { #for all board types
   my ($self, $board, $node1) = @_; #start row/column
   
   my %seen; #indexed by stringified nodes
   my @found;
   my @libs; #liberties
   my @foes; #enemy stones adjacent to string
   my $string_color = $self->stone_at_node($board, $node1);
   return if $string_color==0; #empty
   #color 0 has to mean empty, (1 black, 2 white.)
   my @nodes = ($node1); #array of adjacent intersections to consider
   
   while (@nodes) {
      my $node = pop @nodes;
      next if $seen {$self->node_to_string ($node)};
      $seen {$self->node_to_string ($node)} = 1;
      
      my $here_color = $self->stone_at_node ($board, $node);
      if ($here_color == $string_color){
         push @found, $node;
         push @nodes, $self->node_liberties ($node)
      }
      elsif ($here_color == 0){ #empty
         push @libs, $node;
      }
      else { #enemy
         push @foes, $node;
      }
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
      if ($here_color == 0 or $ignore_stones->{$nodestring}){ #empty
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
      $mask->{$self->node_to_string($n)} = 0;
   }
}

#this returns (terr_mask, [terr_points_b, terr_pts_w], [kill_points_b, kill_pts_w])
sub find_territory_mask{
   my ($self, $board, $death_mask) = @_;
   $death_mask ||= {};
   my %seen; #accounts for all empty nodes.
   my %terr_mask;
   my @terr_points;
   
   for my $node ($self->all_nodes){
      next if $seen{$self->node_to_string($node)};
      my ($empties, $others) = $self->get_empty_space($board, $node, $death_mask);
      next unless @$empties and @$others;
      
      my $terr_color = $self->stone_at_node ($board, $others->[0]);
      my $is_terr = 1; #true, if this space is someone's territory
      for my $stone (@$others){
         next if $death_mask->{$self->node_to_string($stone)};
         $is_terr = 0 unless $self->stone_at_node ($board, $stone) == $terr_color;
      }
      for my $e (@$empties){
         $seen{$self->node_to_string($e)} = 1;
         if ($is_terr){
            $terr_mask{$self->node_to_string($e)} = $terr_color;
            $terr_points[$terr_color]++;
         }
      }
   }
   return (\%terr_mask, \@terr_points);
}

sub count_kills{
   my ($self, $board, $death_mask) = @_;
   my @kills = (undef, 0,0); #[1..2]
   for my $deadnodestring (keys %$death_mask){
      my $node = $self->node_from_string ($deadnodestring);
      my $color = $self->stone_at_node ($board, $node);
      $kills[$color]++;
   }
   return \@kills;
}

1;
