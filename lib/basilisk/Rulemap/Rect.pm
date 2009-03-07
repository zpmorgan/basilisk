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

sub evaluate_move{
   my ($self, $board, $node, $color) = @_;
   die "badcolor $color" unless $color =~ /^[12]$/;
   die (ref $node . $node) unless ref $node eq 'ARRAY';
   die 'badboard' unless ref $board eq 'ARRAY';
   
   my ($row,$col) = @$node;
   if ($board->[$row][$col]){
      return (undef,"stone exists at row $row col $col"); }
   
   #produce copy of board for evaluation -> add stone at $row $col
   my $newboard = [ map {[@$_]} @$board ];
   $newboard->[$row]->[$col] = $color;
   # $string is a list of strongly connected stones: $foes=enemies adjacent to $string
   my ($chain, $libs, $foes) = $self->get_chain($newboard, [$row, $col]);
   my $caps = $self->find_captured ($newboard, $foes);
   if (@$libs == 0 and @$caps == 0){
      return (undef,'suicide');
   }
   for my $cap(@$caps){ # just erase captured stones
      $newboard->[$cap->[0]]->[$cap->[1]] = 0;
   }
   return ($newboard, '', $caps);#no err
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
sub stone_at_node{ #0 if empty, 1 black, 2 white
   my ($self, $board, $node) = @_;
   #die unless $node
   my ($row, $col) = @$node;
   return $board->[$row][$col];
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
   if ($self->{wrap_ns}){
      push @nodes, [($row-1)% $self->h, $col];
      push @nodes, [($row+1)% $self->h, $col];
   }
   else{
      push @nodes, [$row-1, $col] unless $row == 0;
      push @nodes, [$row+1, $col] unless $row == $self->h-1;
   }
   
   if ($self->{wrap_ew}){
      push @nodes, [$row, ($col-1)% $self->w];
      push @nodes, [$row, ($col+1)% $self->w];
   }
   else{
      push @nodes, [$row, $col-1] unless $col == 0;
      push @nodes, [$row, $col+1] unless $col == $self->w-1;
   }
   return @nodes;
}

#return a dgs-filename-like string, such as e, dl, ur
sub node_is_on_edge{
   my ($self, $row, $col) = @_;
   my $string;
   if ($self->{wrap_ns}){
      $string = 'e'
   }
   else {
      if ($row==0) {$string = 'u'}
      elsif ($row==$self->h-1) {$string = 'd'}
      else {$string = 'e'}
   }
   unless ($self->{wrap_ew}){
      if ($col==0) {$string .= 'l'}
      elsif ($col==$self->w-1) {$string .= 'r'}
   }
   return $string;
}

1;
