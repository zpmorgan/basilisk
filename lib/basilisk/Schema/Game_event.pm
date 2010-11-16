package basilisk::Schema::Game_event;
use warnings;
use strict;
use base qw/DBIx::Class/;


__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('Game_event');
__PACKAGE__->add_columns(
   gameid => {data_type => 'INTEGER'},
   event_number => {data_type => 'INTEGER'},
   type => {data_type => 'TEXT'},
   by => {data_type => 'INTEGER'},
   now_phase => {data_type => 'INTEGER', is_nullable => 1 },
   delta => {data_type => 'TEXT', is_nullable => 1}, #JSON.
   time => {data_type => 'INTEGER'},
   time_remaining => {data_type => 'INTEGER', is_nullable => 1},
   periods_remaining => {data_type => 'INTEGER', is_nullable => 1},
);

__PACKAGE__->set_primary_key('gameid', 'event_number');
__PACKAGE__->belongs_to (game => 'basilisk::Schema::Game', 'gameid');
