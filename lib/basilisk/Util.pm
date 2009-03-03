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
   return unpack_position ($pos, $h, $w);
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

#mainly for tests, db spawn
sub board_from_text{
   my ($text, $h, $w) = @_;
   $w = $h unless $w;
   $text =~ s/\s*//g; #rm whitespace
   die "bad data: $text" if $text =~ /([^012])/;
   die 'bad size' unless length $text == $w*$h;
   
   my @list = split '', $text;
   my @board;
   my $row = 0;
   while (@list){
      push @board, [splice @list, 0, $w];
   }
   return \@board;
}

#unused for now
sub board_to_text{
   my ($board) = @_;
   my @lines;
   for my $row (@$board){
      push @lines, join ' ', @$row;
   }
   my $text = join "\n", @lines;
   return $text;
}


use Digest::MD5 'md5'; # qw(md5 md5_hex md5_base64);

sub pass_hash{ #returns binary md5sum
   my $passwd = shift;
   my $hash = md5 $passwd;
   return $hash;
}

1;
