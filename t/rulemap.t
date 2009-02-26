use strict;
use warnings;
use Test::More tests => 4;
use basilisk::Rulemap;


ok(1, 'Ist');
ok(1, 'seconf');

my $rulemap = new basilisk::Rulemap;
isa_ok ($rulemap, 'basilisk::Rulemap');

my $rulemap2 = new basilisk::Rulemap(size => 4);
my $board = Util::board_from_text (
   '0000
    0000
    0000
    0000', 4);

ok ($rulemap2->move_is_valid($board, 2, 2), 'move on empty board valid');

TODO: {
   local $TODO = "URI::Geller not finished";
   
}
