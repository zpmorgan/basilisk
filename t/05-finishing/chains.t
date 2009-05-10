use strict;
use warnings;
use Test::More tests => 10;
use JSON;
use lib qw(t/lib lib);

use basilisk::Util qw/pack_board board_from_text/;

use b_schema;
my $schema = b_schema->init_schema('populate');
use b_mech;
my $mech = b_mech->new;


my @players = $schema->create_players(qw/Sohia Ki Dondai/);


{
   my $game = $schema->create_game (6,6, '0b 1w 2r 3w', @players);
   #3-player oddly perverted
   my $gid = $game->id;
   my $ruleset = $game->ruleset;
   
   my $board = board_from_text ( #give b 6, w 0
   'bb0000
    00r000
    000000
    00r000
    00r000
    0000ww', 6);
   my $pos_data = pack_board($board);
   my $pos_row = $schema->resultset('Position')->create({
      ruleset => $ruleset->id,
      position => $pos_data,
   });
   
   $game->set_column( initial_position => $pos_row->id);
   $game->update;
   
   
   $mech->get_ok("/game/$gid/chains");
   is($mech->ct, "text/json", 'correct group content type');
   my $res = from_json($mech->content);
   my ($delegates, $delegate_of_stone, $delegate_side) = @{$res}{qw/delegates delegate_of_stone delegate_side/};
   
   is (keys %$delegates, 4, '4 delegates, so 4 chains,');
   is ($delegate_side->{'1-2'}, 'r');
   is_deeply ($delegates->{'1-2'}, ['1-2'], 'single-stone group has only node as a delegate');
   is ($delegate_side->{'4-2'} || $delegate_side->{'3-2'}, 'r');
   is ($delegate_side->{'5-4'} || $delegate_side->{'5-5'}, 'w');
   is ($delegate_side->{'0-0'} || $delegate_side->{'0-1'}, 'b');
   is ($delegate_of_stone->{'3-2'}, $delegate_of_stone->{'4-2'}, 'adj. r stones in same chain');
   isnt ($delegate_of_stone->{'1-2'}, $delegate_of_stone->{'3-2'}, 'other r stones not in same chain');
   
}
