package basilisk::Rulemap;
use basilisk::Util;
use strict;
use warnings;


# This class evaluates moves and determines new board positions.
# This class stores no board/position data.
# Also, it must be used to determine visible portions of the board if there's fog of war.
# So you actually MIGHT need one of these to view any game at all.

# Rulemaps are not stored in the database. However they are derived from
#   entries in the Ruleset and Extra_rule tables.
# This is also where parameters relevant to specific rulesets are stored.
#   Example: 'size' might be meaningless for some boards.
#   Example: 'visibility' with fog of war.
#   Example: 'collisions' with fog of war.
# For a ruleset with an arbitrary graph, the whole graph is to be in rulemap.

# This class is basically here to define default behavior and
#   to provide a mechanism to override it.
# However this class will not handle rendering.

# Also: This does not involve the ko rule. That requires a database search 
#   for a duplicate position.

# Note: I'm treating intersections (i.e. nodes) as scalars, which different rulemap 
#   functions may handle as they will. Nodes by default are [$row,$col].
#TODO: shifting turns&teams&colors in new ways (rengo,zen,consensus?)

my %defaults = (
   size => 19,
   topology => 'plane',
   eval_move_func => \&default_evaluate_move,
   node_to_string_func => \&default_node_to_string,
   node_liberties_func => \&default_node_liberties,
   stone_at_node_func => \&default_stone_at_node,
   all_nodes_func     => \&default_all_nodes,
   #move_is_legal_func => sub{'jazzersize'},
);


sub new{
   my $class = shift;
   my %params = @_;
   #copy & modify defaults:
   my $self = { %defaults }; 
   if ($params{size}){
      $self->{size} = $params{size};
   }
   if ($params{topology}){
      $self->{topology} = $params{topology};
   }
   bless $self, $class;
   return $self;
}

#These will be the accessible for any game.
sub move_is_valid{ #returns (true, '') or (false, err)
   my $self = shift;
   return 1 if $self->{eval_move_func}->($self, @_);
}
sub evaluate_move{ #returns (board,'',caps) or (undef, err)
   my $self = shift;
   return  $self->{eval_move_func}->($self, @_);
}
sub node_to_string{ #never use _ in string. - is okay.
   my $self = shift;
   return  $self->{node_to_string_func}->($self, @_);
}
sub node_liberties{
   my $self = shift;
   return  $self->{node_liberties_func}->($self, @_);
}
sub stone_at_node{
   my $self = shift;
   return  $self->{stone_at_node_func}->($self, @_);
}
sub all_nodes{
   my $self = shift;
   return  $self->{all_nodes_func}->($self, @_);
}

#This is the default. Used for normal games on rect grid
sub default_evaluate_move{
   my ($self, $board, $row, $col, $color) = @_;
   die "badcolor $color" unless $color =~ /^[12]$/;
   die "blah" unless defined $row and defined $col;
   die 'badboard' unless ref $board eq 'ARRAY';
   
   if ($board->[$row][$col]){
      return (undef,"stone exists at row $row col $col"); }
   
   #produce copy of board for evaluation -> add stone at $row $col
   my $newboard = [ map {[@$_]} @$board ];
   $newboard->[$row]->[$col] = $color;
   # $string is a list of strongly connected stones: $foes=enemies adjacent to $string
   my ($string, $libs, $foes) = $self->get_string($newboard, [$row, $col]);
   my $caps = $self->find_captured ($newboard, $foes);
   if (@$libs == 0 and @$caps == 0){
      return (undef,'suicide');
   }
   for my $cap(@$caps){ # just erase captured stones
      $newboard->[$cap->[0]]->[$cap->[1]] = 0;
   }
   return ($newboard, '', $caps);#no err
}

#turn [13,3] into 13-3
#TODO: something else for 'go-style' coordinates
sub default_node_to_string{ 
   my ($self, $node) = @_;
   return join '-', @$node;
}
sub default_string_to_node{ 
   my ($self, $string) = @_;
   return [split '-', $string];
}
sub default_stone_at_node{ #0 if empty, 1 black, 2 white
   my ($self, $board, $node) = @_;
   #die unless $node
   my ($row, $col) = @$node;
   return $board->[$row][$col];
}
sub default_all_nodes{ #return square block of coordinates
   my ($self) = @_;
   my ($size) = $self->{size};
   my @nodes;
   for my $i (0..$size-1){
      push @nodes, map {[$i,$_]} (0..$size-1)
   }
   return @nodes;
}

sub default_node_liberties{
   my ($self, $node) = @_;
   my $size = $self->{size};
   my ($row, $col) = @$node;
   my @nodes;
   push @nodes, [$row-1, $col] unless $row == 0;
   push @nodes, [$row+1, $col] unless $row == $size-1;
   push @nodes, [$row, $col-1] unless $col == 0;
   push @nodes, [$row, $col+1] unless $col == $size-1;
   return @nodes;
}

#uses a floodfill algorithm
#returns (string, liberties, adjacent_foes)
sub get_string { #for all board types
   my ($self, $board, $node1) = @_; #start row/column
   my $size = scalar @$board; #assuming square
   
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


#take a list of stones, returns connected strings which have no libs,
sub find_captured{
   my ($self, $board, $nodes) = @_;
   my @nodes = @$nodes; #list
   my %seen; #indexed by stringified node
   my @caps; #list
   while (@nodes){
      my $node = pop @nodes;
      next if $seen {$self->node_to_string($node)};
      my ($string, $libs, $foes) = $self->get_string ($board, $node);
      my $capture_these = scalar @$libs ? '0' : '1';
      for my $n (@$string){
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
      my ($deadstring, $libs, $foes) = $self->get_string ($board, $node);
      for my $deadnode (@$deadstring){
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
         my ($deadnodes, $libs, $foes) = $self->get_string ($board, $node);
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
   my ($alivenodes, $libs, $foes) = $self->get_string ($board, $node);
   for my $n (@$alivenodes){
      $mask->{$self->node_to_string($n)} = 0;
   }
}

#this returns (terr_mask, [terr_points_b, terr_pts_w], [kill_points_b, kill_pts_w])
sub find_territory_mask{
   my ($self, $board, $death_mask) = @_;
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
   my @kills; #[1..2]
   for my $deadnode (keys %$death_mask){
      my $color = $self->stone_at_node ($board, $deadnode);
      $kills[$color]++;
   }
   return \@kills;
}

1;
