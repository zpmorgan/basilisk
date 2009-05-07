package basilisk::Schema::Move;
use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('Move');
__PACKAGE__->add_columns(
    gid         => { data_type => 'INTEGER'},
    movenum     => { data_type => 'INTEGER'},
    position_id => { data_type => 'INTEGER'},
    # dead_groups -- underscore-separated stringified representative nodes
    # like '2-3_5-0_5-6'
    dead_groups => { data_type => 'TEXT', is_nullable => 1}, 
    time        => { data_type => 'INTEGER'},
      #2+ ways to count captures--space-separated values, 
      #Let rulemap take care of it. Both could be done in a game.
      #1. (Positive, as in FFA): has sum of all captures per phase 
      #2. (Negative)Keep track of each side's own lost stones.
      # (atm, it only does 1.)
    captures => { data_type => 'TEXT'}, #'0 0'
    
      #fin--intent of each _phase_ to score (or drop out of the game)
      #intent may be signalled by the passing or resigning
      #'' or '0 0' means everyone is okay. FIN_INTENT_OKAY.
      #if a phase is FIN_INTENT_FIN, it's satisfied, ready to score.
      #if a phase is FIN_INTENT_DROP, then it's skipped
      #  unless a same-sided phase is still OKAY.
      #if every phase is FIN_INTENT_SCORED or FIN_INTENT_DROP,
      #   then consider the game complete
      #also: on each normal move, reset all fins except DROPped ones
    fin => { data_type => 'TEXT', is_nullable => 1}, #'0 0'
    
    phase  => { data_type => 'INTEGER'}, #0, 1, etc
    move   => { data_type => 'TEXT'}, #pass, score, {node}, resign
    #special_stuff => TEXT. or not.
    
    #delta:
    # deltas are used to let users view the board at a previous move
    # by adding/removing stones from the current position.
    # A move delta just contains a keyed list of changes to the previous board position.
    #Here's a delta example:
    #  {
    #    '2-2' => ['remove', {stone => 'w', glyph => '♅'}]
    #  }
    #if for whatever reason, you want to replace a healthy black stone with a diseased white stone:
    #  {
    #    '4-1' => ['update', {stone => 'b'}, {stone => 'w', sick => .65}]
    #  }
    # as sickness isn't mentioned in the 1st state, assume it's 0.
);
__PACKAGE__->set_primary_key('gid', 'movenum');
__PACKAGE__->belongs_to(game => 'basilisk::Schema::Game', 'gid');
__PACKAGE__->belongs_to(position => 'basilisk::Schema::Position', 'position_id');

sub sqlt_deploy_hook {
    my($self, $table) = @_;
    #$table->add_index(name => idx_mv => fields => [qw/gid movenum/]);
}

sub entity{
   my($self) = @_;
   my $phase = $self->phase;
   my $pd = $self->game->phase_description;
   my @phases = split ' ', $pd;
   $phases[$phase] =~ /(\d)/;
   return $1;
}

1
