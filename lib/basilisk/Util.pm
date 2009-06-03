package basilisk::Util;
use strict;
use warnings;

use parent 'Exporter';

our @EXPORT_OK = qw (veryRandShuffle veryRand  random_proverb  pass_hash
           board_from_text unpack_position empty_board empty_pos pack_board ensure_position_size
           cycle_desc to_percent
);

our @schroedingo_symbols = qw/
   ☉ ☽ ☿ ♀ ♂ ♃ ♄ ♅ ♆ ♇ ☊ ☋ ♈ ♉ ♊ ♋ ♌ ♍ ♎ ♏ ♐ ♑ ♒ ♓
   ⤘ ⟲ ⟰ ❡ ❖ ✠ ⚧ ⚕ ♸ ⚓ ⚙ ♞ ♬ ♐ ♑ ☬ ☭ ☨ ⏣ ⏚
   ∰ ⇼ ↯ ↻ ℵ ⅆ ₩ € ฿ ᴪ ᵩ ᵪ ᵟ ᴦ Ϡ ϡ ϰ ϼ ᴧ λ ξ π τ χ
   ͼ ζ Ϟ Ω /;

#todo: unuseful?
our @acceptable_topo = qw/plane cylinder torus mobius klein/;


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

sub veryRand{
   eval "use Math::Random::MT::Auto 'rand'";
   return rand(shift)
}

sub veryRandShuffle{
   eval "use Math::Random::MT::Auto 'shuffle'";
   return shuffle(@_)
}

sub random_proverb{
   require basilisk::Proverbs;
   return basilisk::Proverbs::random_proverb();
}

my %cycle_descs = (
   '0b 1w' => '2-FFA',
   '0b 1w 2r' => '3-FFA',
   '0b 1w 2b 3w' => 'rengo',
   '0b 1w 2b 0w 1b 2w' => 'zen',
   '0b 0w 1w 1r 2r 2b' => '3-player perverse (efficient)', #haha
   '0b 1b 2w 0w 1r 2r' => '3-player perverse',
   '0b 1w 2r 1b 2w 0r' => '3-player skewed perverse',
   '0b 1w 2r 2r 1w 0b' => '3-player skewed FFA', 
   '0b 1w 0r 1b 0w 1r' => 'inverted zen',
);

sub cycle_desc{
   my $pd = shift;
   return $cycle_descs{$pd} if $cycle_descs{$pd};
   return "cycle: ($pd)"; #TODO: try harder with basis & aberrations
}

sub to_percent{
   my $val = shift;
   my $perc = $val * 100;
   $perc = $1 if $perc =~ /^(\d*\.\d)/; #dont be too precise..
   return $perc . '%'; 
}

1;
