package basilisk::Rulemap::Rect;
use Mouse;
extends 'basilisk::Rulemap';

has h  => ( #height
   is => 'ro',
   isa => 'Int',
   default => '19'
);
has w  => ( #width
   is => 'ro',
   isa => 'Int',
   default => '19'
);
has wrap_ns => ( #cylinder/torus
   is => 'ro',
   isa => 'Bool',
   default => 0,
);
has wrap_ew => (
   is => 'ro',
   isa => 'Bool',
   default => 0,
);
has twist_ns => ( #twisting is for mobius/klein
   is => 'ro',
   isa => 'Bool',
   default => 0,
);
has twist_ew => (
   is => 'ro',
   isa => 'Bool',
   default => 0,
);

sub evaluate_move{
   my ($self, $board, $node, $side) = @_;
   die "bad side $side" unless $side =~ /^[bwr]$/;
   #die (ref $node . $node) unless ref $node eq 'ARRAY';
   #die 'badboard' unless ref $board eq 'ARRAY';
   
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
   return ($newboard, '', $caps);#no err
}

sub copy_board{
   my ($self, $board) = @_;
   return [ map {[@$_]} @$board ];
}

#turns [13,3] into 13-3
#TODO: something else for converting 'go-style' coordinates--e8,d6,etc
sub node_to_string{ 
   my ($self, $node) = @_;
   return join '-', @$node;
}
sub node_from_string{ 
   my ($self, $string) = @_;
   return [split '-', $string];
}
sub stone_at_node{ #0 if empty, b black, w white, r red, etc
   my ($self, $board, $node) = @_;
   my ($row, $col) = @$node;
   return $board->[$row][$col];
}
sub set_stone_at_node{
   my ($self, $board, $node, $side) = @_;
   my ($row, $col) = @$node;
   $board->[$row][$col] = $side;
}
sub all_nodes{ #return list coordinates
   my ($self) = @_;
   my @nodes;
   for my $i (0..$self->h-1){
      push @nodes, map {[$i,$_]} (0..$self->w-1)
   }
   return @nodes;
}

sub node_liberties{
   my ($self, $node) = @_;
   my ($row, $col) = @$node;
   my @nodes;
   if ($self->wrap_ns){
      push @nodes, [($row-1)% $self->h, $col];
      push @nodes, [($row+1)% $self->h, $col];
   }
   else{
      push @nodes, [$row-1, $col] unless $row == 0;
      push @nodes, [$row+1, $col] unless $row == $self->h-1;
      if ($self->twist_ns){ #klein, etc.
         push @nodes, [($row-1)% $self->h, ($self->w-1)- $col] if $row == 0;
         push @nodes, [($row+1)% $self->h, ($self->w-1)- $col] if $row == $self->h-1;
      }
   }
   
   if ($self->wrap_ew){
      push @nodes, [$row, ($col-1)% $self->w];
      push @nodes, [$row, ($col+1)% $self->w];
   }
   else{
      push @nodes, [$row, $col-1] unless $col == 0;
      push @nodes, [$row, $col+1] unless $col == $self->w-1;
      if ($self->twist_ew){
         push @nodes, [($self->h-1)- $row, ($col-1)% $self->w] if $col == 0;
         push @nodes, [($self->h-1)- $row, ($col+1)% $self->w] if $col == $self->w-1;
      }
   }# die map {$self->node_to_string($_)} @nodes;
   return @nodes;
}

#return a dgs-filename-like string, such as e, dl, ur
sub node_is_on_edge{
   my ($self, $row, $col) = @_;
   my $string;
   if ($self->wrap_ns or $self->twist_ns){
      $string = 'e'
   }
   else {
      if ($row==0) {$string = 'u'}
      elsif ($row==$self->h-1) {$string = 'd'}
      else {$string = 'e'}
   }
   unless ($self->wrap_ew or $self->twist_ew){
      if ($col==0) {$string .= 'l'}
      elsif ($col==$self->w-1) {$string .= 'r'}
   }
   return $string;
}

my @cletters = qw/a b c d e f g h j k l m n o p q r s t u v w x y z/;

sub pretty_coordinates{ #convert 1-1 to b18, etc
   my ($self, $node) = @_;
   my ($row,$col) = $node =~ /^(\d+)-(\d+)$/;
   $col = $cletters[$col];
   $row = $self->h - $row;
   
   return "'$col$row'" if $self->twist_ns; #non-orientable, so "
   return "$col$row";
}
1;
