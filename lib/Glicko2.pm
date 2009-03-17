package Glicko2;
use warnings;
use strict;
# http://math.bu.edu/people/mg/glicko/glicko2.doc/example.html

#step 1
my $default_tau = 1.2; #system constant
my $default_rating = 0; #== 1500 in glicko2;
my $default_rd = 2; # == 350 in glicko2;

#Step 2: get list of past games
sub compute_rating{
   my ($r,$rd,$rv, $games, $tau) = @_;
   die 'glicko2 requires data' unless @$games;
   $tau = $default_tau unless $tau;
   # @$past_games requires opponents' r and rd from the time the game was played
   # each past game is {r=>opponent's r, rd=>opponent's rd, s=>player beat opponent ?1 :0}
   
   #Step 3: compute $v
    #$v is the estimated variance of the team's/player's 
    #rating based only on game outcomes.
   sub g{
      my $rd=shift;
      return 1 / sqrt (1 + (3*($rd**2)/3.14**2))
   }
   sub E{
      my ($r, $o_r, $o_rd) = @_;
      return 1 / (1 + exp(-1*g($o_rd) * ($r-$o_r)))
   }
   my $v_sum=0;
   for my $pg (@$games){
      my ($o_r,$o_rd) = @{$pg}{qw/r rd/};
      my $e = E($r,$o_r,$o_rd);
      $v_sum += g($o_rd)**2 * $e * (1-$e);
   }
   my $v = 1/$v_sum;
   #Step 4: compute $delta
   my $delta = 0;
   for my $pg (@$games){
      my ($o_r,$o_rd, $win) = @{$pg}{qw/r rd win/};
      $delta += g($o_rd) * ($win - E($r,$o_r,$o_rd));
   }
   $delta *= $v;
   #Step 5: compute rating volatility $new_rv
   my $a = log($rv**2);
   my $x = $a;
   while (1){
      my $d = $rd**2 + $v + exp($x);
      my $h1 = -($x-$a)*($tau**2) - .5*exp($x)/$d + .5*exp($x)*($delta/$d)**2;
      my $h2 = -1/$tau**2 - .5*exp($x)*($rd**2+$v)/$d**2 + .5*$delta**2*exp($x)*($rd**2+$v-exp($x))/$d**3;
      my $next_x = $x - $h1/$h2;
      last unless abs($x-$next_x) > .0000001;
      $x = $next_x;
   }
   my $new_rv = exp($x/2);
   #step 6: find new pre-rating period value---phi*
   my $blah = sqrt($rd**2 + $new_rv**2);
   #step 7: find new_r and new_rd
   my $new_rd = 1 / sqrt((1/$blah**2) + (1/$v));
   my $new_r = 0; #sum
   for my $pg (@$games){
      my ($o_r,$o_rd, $win) = @{$pg}{qw/r rd win/};
      $new_r += g($o_rd) * ($win - E($r,$o_r,$o_rd));
   }
   $new_r *= $new_rd**2;
   
   return ($new_r, $new_rd, $new_rv)
}


sub default_rating{
   return (0, 2, 0.06); #r,rd,rv
}
