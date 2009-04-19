package basilisk::Rulemap::Rect;
use Moose;
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


sub copy_board{
   my ($self, $board) = @_;
   return [ map {[@$_]} @$board ];
}

#turns [13,3] into 13-3
#see also &pretty_coordinates
sub node_to_string{ 
   my ($self, $node) = @_;
   return join '-', @$node;
}
sub node_from_string{ #return undef if invalid
   my ($self, $string) = @_;
   return unless $string =~ /^(\d+)-(\d+)$/;
   return unless $1 < $self->h;
   return unless $2 < $self->w;
   return [$1,$2];
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
