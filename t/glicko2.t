use strict;
use warnings;
use Test::More tests => 3;
use Number::Tolerant;

use lib qw/lib/;
use Glicko2;

#tests are from http://math.bu.edu/people/mg/glicko/glicko2.doc/example.html
my ($r, $rd, $rv) = (0, 1.1513, .06);
my $tau = .5;
my $games = [
   {r => -.5756, rd => .1727, win=>1},
   {r => .2878,  rd => .5756, win=>0},
   {r => 1.1513, rd => 1.7269,win=>0},
];

my ($new_r, $new_rd, $new_rv) = Glicko2::compute_rating ($r, $rd, $rv, $games, $tau);

ok($new_r == tolerance(-.2069 => plus_or_minus => .01));
ok($new_rd == tolerance(.8722 => plus_or_minus => .01));
ok($new_rv == tolerance(.05999 => plus_or_minus => .001));

