
use strict;
use warnings;

#let's use 1 byte per intersection. This leaves room for more data
sub EMPTY{0}
sub BLACK{1}
sub WHITE{2}



#from lists to blob
sub pack_board{
   my ($board,$h,$w) = @_;
   my $blob
   for my $row (@$board){
      $blob .= pack ('C*',@$_)
   }
   return $blob;
}

#from blob to lists
sub unpack_board{
   my ($blob, $h,$w) = @_;
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
   my $h, $w;
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
