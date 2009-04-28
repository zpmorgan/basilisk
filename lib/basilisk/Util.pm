package Util;
use strict;
use warnings;
use basilisk::Proverbs;

# These are different on the span server:
sub IMG_BASE{'/g'}
sub URL_BASE{''}
#sub IMG_BASE{'/basilisk/g'}
#sub URL_BASE{'/basilisk/go'}

# using 1 byte per intersection in storage, hopefully in the most natural order
sub EMPTY{0}
sub BLACK{'b'}
sub WHITE{'w'}

#values for game's status column
sub RUNNING {1}
sub FINISHED {2}
sub PAUSED {3} #unused..

sub INVITEE_OPEN {1}
sub INVITEE_ACCEPTED {2}
sub INVITEE_REJECTED {3}
# not the same as: 
sub INVITE_OPEN {1}
sub INVITE_ACCEPTED {2}
sub INVITE_REJECTED {3}

sub INVITE_ORDER_SPECIFIED {1}
sub INVITE_ORDER_RANDOM {2}

sub WGAME_ORDER_RANDOM {1}
sub WGAME_ORDER_PROPOSER_FIRST {2}
sub WGAME_ORDER_PROPOSER_LAST {3}

sub MESSAGE_NOT_SEEN {1}
sub MESSAGE_SEEN {2}

#these values are used lot directly. (without being called)
sub FIN_INTENT_OKAY {0}
sub FIN_INTENT_FIN {1} #ready to score
sub FIN_INTENT_SCORED {2}
sub FIN_INTENT_DROP {3}

#todo: unused?
our @acceptable_topo = qw/plane cylinder torus mobius klein/;

sub wgame_order_str{
   my $order = shift;
   return 'random' if $order == Util::WGAME_ORDER_RANDOM();
   return 'proposer first' if $order == Util::WGAME_ORDER_PROPOSER_FIRST();
   return 'proposer first' if $order == Util::WGAME_ORDER_PROPOSER_LAST();
   die $order;
}

sub invite_order_str{
   my $order = shift;
   return 'random' if $order == Util::INVITE_ORDER_RANDOM();
   return 'specified' if $order == Util::INVITE_ORDER_SPECIFIED();
   die $order;
}


#rect-only stuff--mv to rulemap::rect.
#Or not, they're are pretty convenient here.

sub empty_pos{ #create a long string of unset bits
   my ($h,$w) = @_;
   $w = $h unless $w;
   my $blob = '';
   #my @empty_row = map {0} (1..$w);
   for my $row (1..$h){
      $blob .= 0 x $w
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
      $blob .= join '', @$row
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
      push @board, [split '', $blobrow];
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
   die "bad data: $text" if $text =~ /([^0bwr])/;
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
