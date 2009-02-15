package Util;
use strict;
use warnings;

# using 1 byte per intersection in storage.
sub EMPTY{0}
sub BLACK{1}
sub WHITE{2}


sub empty_pos{ #create a long string of unset bits
   my ($h,$w) = @_;
   $w = $h unless $w;
   my $blob = '';
   my @empty_row = map {0} (1..$w);
   for my $row (1..$h){
      $blob .= pack ('C*', @empty_row)
   }
   return $blob;
}

sub empty_board{ #return list of lists
   my ($h,$w) = @_;
   my $pos = empty_pos($h, $w);
   return unpack_position ($pos, $h, $w);
}

#from lists to position blob
sub pack_board{
   my ($board,$h,$w) = @_;
   $w = $h unless $w;
   my $blob = '';
   for my $row (@$board){
      $blob .= pack ('C*',@$row)
   }
   return $blob;
}

#from position blob to lists
sub unpack_position{
   my ($blob, $h,$w) = @_;
   $w = $h unless $w;
   my @board;
   for my $r (0..$h-1){
      my $blobrow = substr($blob, $r*$w, $w);
      push @board, [unpack('C*', $blobrow)];
   }
   return \@board;
}

#untested
sub board_from_text{
   my $text = shift;
   my ($h, $w) = @_;
   $w = $h unless $w;
   chomp $text;
   my @board;
   my @lines = split "\n", $text;
   $h = scalar @lines;
   for (@lines){
      chop $_ if / $/; #rm whitespace at end
      my @line = split (/ /, $_);
      @line = map {tr/XO[.+]/12 /; $_ } @line;
      #warn @line;
      push @board, \@line;
   }
   return \@board;
}

#incomplete
sub board_to_text{
   my ($board) = @_;
   my @lines;
   for my $row (@$board){
      push @lines, join ' ', @$row;
   }
   my $text = join "\n", @lines;
   $text =~ tr/12/XO/;
}

#use a floodfill algorithm
sub get_string { #for vanilla boards
   my ($board, $srow, $scol) = @_; #start row/column
   my $size = scalar @$board; #assuming square
   
   my @seen;
   my @found;
   my @libs; #liberties
   my $color = $board->[$srow][$scol];
   return if $color==0; #empty
   #color 0 has to mean empty, (1 black, 2 white.)
   my @nodes = ([$srow,$scol]); #array of adjacent intersections to consider
   
   while (@nodes) {
      my ($row, $col) = @{pop @nodes};
      next if $seen[$row][$col];
      $seen[$row][$col] = 1;
      if ($board->[$row][$col] == $color){
         push @found, [$row, $col];
         push @nodes, [$row-1, $col] unless $row <= 0;
         push @nodes, [$row+1, $col] unless $row >= $size;
         push @nodes, [$row, $col-1] unless $col <= 0;
         push @nodes, [$row, $col+1] unless $col >= $size;
      }
      elsif ($board->[$row][$col] == 0){ #empty
         push @libs, [$row, $col];
      }
   }
   return (\@found, \@libs);
}

1;
