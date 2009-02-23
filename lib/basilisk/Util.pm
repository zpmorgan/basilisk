package Util;
use strict;
use warnings;
use basilisk::Proverbs;

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
   $w = $h unless $w;
   my $pos = empty_pos($h, $w);
   return [unpack_position ($pos, $h, $w)];
}

#from lists to position blob
sub pack_board{
   my ($board) = @_;
   
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

#see if wrong size position somehow -- die if fail!
# ascii translate: http://www.paulschou.com/tools/xlate/
sub ensure_position_size{
   my ($position, $h,$w) = @_;
   $w = $h unless $w;
   return if length $position == $h*$w; #correct size
   
   my $newsize = length $position; 
   my $newstring = join ' ',unpack ('C*', $position);
   die "position data is size $newsize, should be size ".$h*$w . "|||\n".$newstring;
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
   #$text =~ tr/12/XO/;
   return $text;
}

#use a floodfill algorithm
#returns (string, liberties, adjacent_foes)
sub get_string { #for vanilla boards
   my ($board, $srow, $scol) = @_; #start row/column
   my $size = scalar @$board; #assuming square
   
   my @seen;
   my @found;
   my @libs; #liberties
   my @foes; #enemy stones adjacent to string
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
         push @nodes, [$row-1, $col] unless $row == 0;
         push @nodes, [$row+1, $col] unless $row == $size-1;
         push @nodes, [$row, $col-1] unless $col == 0;
         push @nodes, [$row, $col+1] unless $col == $size-1;
      }
      elsif ($board->[$row][$col] == 0){ #empty
         push @libs, [$row, $col];
      }
      else { #empty
         push @foes, [$row, $col];
      }
   }
   return (\@found, \@libs, \@foes);
}

#take a list of stones, returns connected strings which have no libs,
sub find_captured{
   my ($board, $nodes) = @_;
   my @nodes = @$nodes; #list
   my @seen; #grid. 
   my @caps; #list
   while (@nodes){
      my ($row, $col) = @{pop @nodes};
      next if $seen[$row][$col];
      my ($string, $libs, $foes) = get_string ($board, $row, $col);
      my $mark = scalar @$libs ? 'safe' : 'cap';
      for my $s (@$string){
         $seen[$s->[0]][$s->[1]] = 1;
         push @caps, $s if $mark eq 'cap';
      }
   }
   return \@caps
}

sub death_mask_from_list{ #list of dead stones into a board mask
   my $list = shift;
   my @mask;
   for (@$list){
      $mask[$_[0]][$_[1]] = 1;
   }
   return \@mask;
}
sub death_mask_to_list{
   my $mask = shift;
   my @list;
   my $rownum=0;
   for my $row (@$mask){
      $rownum++;
      next unless defined $row;
      for my $colnum (1..@$row){
         if ($row->[$colnum]){ #marked dead
            push @list, [$rownum, $colnum];
         }
      }
   }
   return \@list;
}
#floodfill through empty space.
#flips elements of $mask, connected through empties.
sub update_death_mask{ 
   my ($board, $mask, $action, $srow,$scol) = @_;
   my $size = scalar @$board;
   my $to = $action eq 'mark_dead' ? 1 : 0;
   my $color = $board->[$srow][$scol];
   return unless $color;
   my @nodes = ([$srow,$scol]); #list
   my @seen; #grid.
   while (@nodes){
      my ($row, $col) = @{pop @nodes};
      next if $seen[$row][$col];
      $seen[$row][$col] = 1;
      my $board_color = $board->[$row][$col];
      next unless ($board_color == $color)  or  ($board_color == 0);
      if ($board_color == $color){
         $mask->[$row][$col] = $to;
         push @nodes, [$row-1, $col] unless $row == 0;
         push @nodes, [$row+1, $col] unless $row == $size-1;
         push @nodes, [$row, $col-1] unless $col == 0;
         push @nodes, [$row, $col+1] unless $col == $size-1;
      }
   }
}

use Digest::MD5 'md5'; # qw(md5 md5_hex md5_base64);

sub pass_hash{ #returns binary md5sum
   my $passwd = shift;
   my $hash = md5 $passwd;
   return $hash;
}

1;
