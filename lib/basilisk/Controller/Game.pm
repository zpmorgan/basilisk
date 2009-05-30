package basilisk::Controller::Game;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use basilisk::Rulemap;
use JSON;

use basilisk::Util qw/unpack_position pack_board ensure_position_size /; 
use basilisk::Constants qw{ GAME_RUNNING GAME_FINISHED GAME_PAUSED
         FIN_INTENT_DROP FIN_INTENT_FIN FIN_INTENT_OKAY FIN_INTENT_SCORED};

#__PACKAGE__->config->{namespace} = '';

# /game
sub default :Path {
   my ( $self, $c ) = @_;
   $c->forward('game');
   $c->forward('render');
}
#grid nodes are [row,col] starting at top-left
#Note: death_mask and territory_mask should not be stored in the database.
# what you need to get them is a list of dead groups.

#all these actions may affect the view depending on which of these it sets:
# $c->stash->{board_clickable}
# $c->stash->{marking_dead_stones}
# $c->stash->{territory_mask}
# $c->stash->{death_mask}
#and for cgi params: $c->stash->{caps}? (or not..)

# /game/14/move/4-4
# /game/14/pass
sub game : Chained('/') PathPart('game') CaptureArgs(1){ 
   my ( $self, $c, $gameid) = @_;
   unless ($gameid ){
      $c->go ('invalid_request', ['please supply a game id']);
   }
   $c->stash->{gameid} = $gameid;
   my $game = $c->model('DB::Game')->find ({'id' => $gameid}, {cache => 1});
   $c->stash->{game} = $game;
   unless ($game){
      $c->go ('invalid_request', ["no game with id $gameid"]);
   }
   $c->stash->{ruleset} = $game->ruleset;
   
   $c->forward('build_rulemap');
   my $pos_data = $game->current_position;
   my $h = $game->h;
   my $w = $game->w;
   my $rulemap = $c->stash->{rulemap};
   my $board = unpack_position($pos_data, $h, $w);
   @{$c->stash}{qw/old_pos_data board/} = ($pos_data, $board); #put board data in stash
   @{$c->stash}{qw/entity side/} = $game->turn; #phase data in stash
} #now c does chained actions:  move, pass, resign, think

sub render: Private{
   my ($self, $c) = @_;
   my ($rulemap, $board, $gameid) = @{$c->stash}{qw/rulemap board gameid/};
   #game's state may be altered:
   my $game = $c->stash->{game} = $c->model('DB::Game')->find ({'id' => $gameid});
   die 'wat' unless $game;
   my $lastmove = $game->last_move;
   my ($entity, $side) = $game->turn;
   
   if ($c->forward ('permission_to_move')){ #your turn
      $c->stash->{board_clickable} = 1;
   }
   else {
      $c->stash->{board_clickable} = 0;
   }
   
   #now decide whether marked to show marked stones, and whether to provide chain data for marking..
   if ($game->status == GAME_FINISHED){
      #show stones that were dead at finish?
      #dont bother if it looks like a resign, etc
      if ($lastmove and $lastmove->move eq 'think'){
         $c->forward('provide_all_chains', [$lastmove->dead_groups]);
         $c->stash->{should_score} = 0;
      }
   }
   elsif ($lastmove and $lastmove->move eq 'think'){
      $c->forward('provide_all_chains', [$lastmove->dead_groups]);
      $c->stash->{should_score} = 1;
   }
   elsif ($c->forward('permission_to_move')){
      #no score by default, but it is an option
      $c->forward('provide_all_chains', ['']); #start with no deads
      $c->stash->{should_score} = $game->no_phases_are_okay() ? 1 : 0;
   }
   
   
   if ($rulemap->topology eq 'C20'){ #todo: ...use some day?
      $c->stash->{topo} = 'graph';
      $c->stash->{nodes} = $rulemap->all_node_coordinates;
      $c->stash->{edges} = $rulemap->node_adjacency_list;
      $c->stash->{stones} = $board;
   }
   else{ #grid
      $c->stash->{json_board_pos} = $c->forward('json_board_pos');
      $c->stash->{json_initial_board} = $c->forward('json_initial_board');
      $c->stash->{h} = $rulemap->h;
      $c->stash->{w} = $rulemap->w;
      $c->stash->{wrap_ns} = $rulemap->wrap_ns;
      $c->stash->{wrap_ew} = $rulemap->wrap_ew;
      $c->stash->{twist_ns} = $rulemap->twist_ns;
   }
   $c->forward ('get_game_phase_data');
   $c->forward ('get_game_moves');
   $c->stash->{game_running} = $game->status==GAME_RUNNING ?1:0;
   $c->stash->{title} = "Game " . $c->stash->{gameid}.", move " . $game->num_moves;
   
   $c->stash->{to_move_side} = $side;
   $c->stash->{to_move_player} = $c->stash->{game}->player_name_to_move_next;
   $c->stash->{result} = $game->result;
   
   $c->stash->{rules_description} = $c->stash->{ruleset}->rules_description;
   $c->stash->{komi} = $c->stash->{ruleset}->komi;
   
   my $comments = $c->forward(qw/basilisk::Controller::Comments all_comments/);
   $c->stash->{json_comments} = to_json ($comments);
   $c->stash->{template} = 'game.tt';
}# now goes to template

#view this game
sub view : Chained('game') {
   my ($self, $c) = @_;
   $c->forward('render');
}

sub move : Chained('game') Args(1){ #evaluate & do move:
   my ($self, $c, $nodestring) = @_;
   unless ($c->forward ('permission_to_move')){
      $c->stash->{msg} = "permission fail: ".$c->stash->{whynot};
      $c->detach('render');
   }
   my ($game, $rulemap, $oldboard) = @{$c->stash}{ qw/game rulemap board/ };
   #extract coordinates from url:
   my $node = $rulemap->node_from_string ($nodestring);
   unless ($node){
      $c->stash->{msg} = "move is failure: $nodestring not a valid node.";
      $c->detach('render');
   }
   
   $c->forward('evaluate_move', [$node, $oldboard]);
   if ($c->stash->{eval_move_fail}){
      $c->stash->{msg} = "move is failure: ".$c->stash->{eval_move_fail};
      $c->detach('render');
   }
   
   my ($newboard, $caps) = @{$c->stash}{ qw/newboard newcaps/ };
   #dunno how to handle the heisengo discrepency. overwrite $node for now.
   $node = $c->stash->{newnode};
   
   my $h = $c->stash->{game}->h;
   my $w = $c->stash->{game}->w;
   my $new_pos_data = pack_board ($newboard, $h, $w);
   ensure_position_size($new_pos_data, $h, $w); #sanity?
   
   
   #perhaps txn wrong somehow. I think capture count can get messed up.
   $c->model('DB')->schema->txn_do(  sub{
      #update capture count:
      my $captures = $game->captures;
      unless (defined $captures) {$captures = $rulemap->default_captures}
      my $new_captures = $captures;
      if ($caps and @$caps){ #update capture count
         my @phase_caps = split ' ', $game->captures;
         $phase_caps[$game->phase] += @$caps;
         $new_captures = join ' ', @phase_caps;
      }
      
      my $posrow = $c->model('DB::Position')->create( {
         ruleset => $c->stash->{ruleset}->id,
         position => $new_pos_data,
      });
      
      my $mv = '{' . $rulemap->node_to_string($node) . '}';
      $game->create_related( 'moves', {
         position_id => $posrow->id,
         move => $mv,
         phase => $game->phase,
         movenum => $game->num_moves+1,
         time => time,
         captures => $new_captures,
         fin => $game->fin,
      });
      $game->clear_fin_intent(); #clear any intent to score,etc
      my $next_phases = $c->forward('phases_to_choose_from');
      my $nextphase = $rulemap->determine_next_phase($game->phase, $next_phases);
      $game->shift_phase($nextphase);
   });
   $c->stash->{board} = $newboard;
   $c->stash->{msg} = 'move is success';
   $c->forward('render');
}

sub pass : Chained('game') { #evaluate & do pass: Args(0)
   my ($self, $c) = @_;
   unless ($c->forward ('permission_to_move')){
      $c->stash->{msg} =  "permission fail: ".$c->stash->{whynot};
      $c->detach('render');
   }
   my ($game, $rulemap) = @{$c->stash}{ qw/game rulemap/ };
   my ($entity, $side) = $game->turn;
   #whether this entity's other phases should be marked _FIN
   my $pass_all = $c->req->param('pass_all'); 
   #transaction!
   $c->model('DB')->schema->txn_do(  sub{
      $game->create_related( 'moves',
         {
            phase => $game->phase,
            move => 'pass',
            position_id => $game->current_position_id,
            movenum => $game->num_moves+1,
            time => time,
            captures => $game->captures,
            fin => $game->fin,
         });
      $game->signal_fin_intent (FIN_INTENT_FIN, $pass_all);
      my $next_phases = $c->forward('phases_to_choose_from');
      my $nextphase = $rulemap->determine_next_phase($game->phase, $next_phases);
      $game->shift_phase($nextphase);
   });
   $c->stash->{msg} = 'pass is success';
   $c->forward('render');
}

#at least one phase wants to drop out!
sub resign : PathPart('resign') Chained('game'){ 
   my ($self, $c) = @_;
   unless ($c->forward ('permission_to_move')){
      $c->stash->{msg} =  "permission fail: ".$c->stash->{whynot};
      $c->detach('render');
   }
   my $rulemap = $c->stash->{rulemap};
   my $game = $c->stash->{game};
   my $resign_all = $c->req->param('resign_all');
   
   my ($entity, $side) = $game->turn;
  # my @sides = $rulemap->all_sides;
  # my $winning_side = $sides[0] eq $side ? $sides[1] : $sides[0];
  # my $result = $winning_side . " + resign";
   
   #transaction!
   $c->model('DB')->schema->txn_do(  sub{
      $game->create_related( 'moves',
         {
            position_id => $game->current_position_id,
            phase => $game->phase,
            move  => 'resign',
            movenum => $game->num_moves+1,
            time => time,
            captures => $game->captures,
            fin => $game->fin,
         });
      $game->signal_fin_intent (FIN_INTENT_DROP(), $resign_all);
      $game->clear_fin_intent (); #this upsets the balance, so reset _FIN and _SCORED
      my $winner = $game->winner_by_resignation;
      if (defined $winner){
         $game->set_column ('status', GAME_FINISHED());
         $game->set_column ('result', $winner.'+resign');
         $game->update();
      }
      else{
         my $next_phases = $c->forward('phases_to_choose_from');
         my $nextphase = $rulemap->determine_next_phase($game->phase, $next_phases);
         $game->shift_phase($nextphase);
      }
   });
   $c->stash->{msg} = 'You have resigned';
   $c->forward('render');
}

#use fin to signal intent to wrap things up
#and take dead groups that player wants dead.
#if these dead groups == prev_move's dead groups, just change ent's intent(s)
#if these dead groups != prev_move's dead groups, clear intent of other phases.

#unlike DGS, you should be allowed to submit deads without passing first

#This replaces submit_dead_selection and wants_to_stop_scoring and mark_dead_or_alive
sub think: PathPart('think') Chained('game'){
   my ($self, $c, $deads) = @_;
   $deads ||= '';
   unless ($c->forward ('permission_to_move')){ #...to_score
      $c->stash->{msg} =  "permission fail: ".$c->stash->{whynot};
      $c->detach('render');
   }
   
   my $rulemap = $c->stash->{rulemap};
   my ($game,$board,$ruleset) = @{$c->stash}{qw/game board ruleset/};
   my $think_all = 1; #always true....
   
   my ($entity, $side) = $game->turn;
   
   #not generic. do with rulemap.
   my @new_deads = $rulemap->nodestrings_to_list ($deads);
   my $new_death_mask = $rulemap->death_mask_from_list($board, \@new_deads);
   
   my $prev_deads = $game->deads;
   my @old_deads = $rulemap->nodestrings_to_list ($prev_deads);
   my $old_death_mask = $rulemap->death_mask_from_list($board, \@old_deads);
   
   my $equal_marks = $rulemap->compare_masks ($old_death_mask, $new_death_mask);
   my @new_death_list = $rulemap->death_mask_to_list($board, $new_death_mask);
   my $deadgroupsstring = $rulemap->nodestrings_from_list (\@new_death_list);
   
   $c->model('DB')->schema->txn_do(  sub{
      $game->create_related( 'moves',
         {
            position_id => $game->current_position_id,
            phase => $game->phase,
            move  => 'think',
            movenum => $game->num_moves+1,
            time => time,
            captures => $game->captures,
            dead_groups => $deadgroupsstring,
            fin => $game->fin,
         });
      unless ($equal_marks){
         $game->clear_fin_scored (); #if this upsets the balance, reset _SCORED to _FIN
      }
      $game->signal_fin_intent (FIN_INTENT_SCORED(), $think_all);
      my $done = $game->done_thinking;
      if ($done){ #game's over
         my $score = $rulemap->compute_score($board, $game->captures, $new_death_mask);
         my @ordered_sides = $ruleset->sides;
         my $result = join ' ', map{"$_ ".$score->{$_}} @ordered_sides;
         #result should be something like 'b 4 w 12'
         $game->set_column ('status', GAME_FINISHED());
         $game->set_column ('result', $result);
         $game->update();
         $c->stash->{msg} = 'Game finished successfully';
      }
      else{
         my $next_phases = $c->forward('phases_to_choose_from');
         my $nextphase = $rulemap->determine_next_phase($game->phase, $next_phases);
         $game->shift_phase($nextphase);
         $c->stash->{msg} = 'Thought submitted successfully';
      }
   });
   $c->forward('render');
}

sub phases_to_choose_from : Private{
   my ($self, $c) = @_;
   my $game = $c->stash->{game};
   my @next_phases = $game->okay_phases();
   unless (@next_phases){ #everyone's ready to score.
      @next_phases = $game->fin_phases();
   }
   unless (@next_phases){ #everyone's ready to score.
      die 'should the game be over?'
   }
   #catalyst coerces multiple return values into one, so return arrayref
   return \@next_phases;
}


sub invalid_request : Private{
   my ($self, $c, $err) = @_;
   $c->stash->{message} = "Invalid request: $err";
   $c->stash->{template} = 'message.tt';
}


#sets $c->stash->{whynot} error. returns 1 if true
#TODO: handle surrogates! and set {surrogate} in stash!
#perhaps return 'true' | 'false' | 'surrogate'
sub permission_to_move : Private{
   my ($self, $c) = @_;
   delete $c->stash->{entity};
   delete $c->stash->{my_side};
   
   $c->stash->{whynot} = '';
   $c->stash->{whynot} = 'not logged in' unless $c->session->{logged_in};
   return 0 if $c->stash->{whynot};
   #$c->stash->{whynot} = 'not registered' if $c->session->{userid} == 1;
   #return 0 if $c->stash->{whynot};
   
   my $game = $c->stash->{game};
   unless ($game->status == GAME_RUNNING()){
      $c->stash->{whynot} = 'Game is already finished!';
      return 0
   }
   my ($entity, $side) = $game->turn;
   my $gid = $game->id;
   my $p = $c->model('DB::player_to_game')->find( {
       gid => $gid,
       entity => $entity,
   }); 
   
   unless ($p){
      $c->stash->{whynot} = "entity $entity not found for game $gid";
      return 0 
   }
   unless ($c->session->{userid} == $p->pid){
      $c->stash->{whynot} = 'not your turn.' unless $c->session->{userid} == $p->pid;
      return 0 
   }
   
   #success
   #return 'strange' unless $entity == $p->entity;
   $c->stash->{p2g} = $p; #unused..
   $c->stash->{entity} = $entity;
   $c->stash->{my_side} = $side;
   return 1
}


sub build_rulemap : Private{
   my ($self, $c) = @_;
   my $game = $c->stash->{game};
   my $ruleset = $game->ruleset;
   my $pd = $ruleset->phase_description;
   
   my $rules = from_json $ruleset->other_rules;
   my $topo = $rules->{topo};
   
   my $rulemap = new basilisk::Rulemap::Rect(
      h => $game->h,
      w => $game->w,
      wrap_ew => ($topo eq 'torus' or $topo eq 'cylinder' or $topo eq 'klein') ?1:0,
      wrap_ns => ($topo eq 'torus') ?1:0,
      twist_ew => 0,
      twist_ns => ($topo eq 'klein' or $topo eq 'mobius') ?1:0,
      topology => $topo,
      phase_description => $pd,
      komi => $ruleset->komi,
   );
   if ($rules->{heisengo}){
      $rulemap->apply_rule_role ('heisengo', $rules->{heisengo});
   }
   if ($rules->{planckgo}){
      $rulemap->apply_rule_role ('planckgo', $rules->{planckgo});
   }
   if ($rules->{schroedingo}){
      $rulemap->apply_rule_role ('schroedingo');
   }
   $c->stash->{rulemap} = $rulemap;
}

#todo: situational vs positional as an option.. Would anyone care?
#situational is default now.
sub detect_duplicate_position{
   my ($c, $newboard) = @_;
   my $game = $c->stash->{game};
   #todo, use ruleset...
   my $h = $game->h;
   my $w = $game->w;
   my $newpos = pack_board($newboard, $h, $w);
   
   #search position table for the same board state from the same game
   my @similar_moves = $game->search_related ( 'moves',
     {
      'position.position' => $newpos,
     },{
      'join' => 'position',
      '+select' => [ 'position.position'],
      '+as'     => [ 'oldpos' ],
   });
   my $now_side = $game->side_of_phase($game->phase);
   for my $mv (@similar_moves){
      #situational superko: compare side AND position
      my $side = $game->side_of_phase($mv->phase);
      next unless $side eq $now_side;
      #And another position comparison..sqlite seems to get false positives..
      next unless $mv->get_column('oldpos') eq $newpos;
      $c->stash->{oldmove} = $mv;
      return 1
   }
   #no dupes..
}

#this wraps the rulemap method to set stash values and detect ko
sub evaluate_move : Private{
   my ($self, $c, $node, $board) = @_;
   my $side = $c->stash->{my_side};
   die $side unless $side =~ /^[bwr]$/;
   $c->stash->{eval_move_fail} = '';
   #find next board position:
   my ($newboard, $err, $caps, $newnode) = $c->stash->{rulemap}->evaluate_move
         ($board,$node,$side);
   unless ($newboard){
      $c->stash->{eval_move_fail} = $err;
      return
   }
   if (detect_duplicate_position($c, $newboard)){
      $c->stash->{eval_move_fail} = 'Ko error: this is a repeating position from move '.$c->stash->{oldmove}->movenum;
      return;
   }
   @{$c->stash}{ qw/newboard newcaps newnode/ } = ($newboard, $caps, $newnode);#no err
}

#by default, phases are shown, with the active phase displayed
#TODO: either congeal here, or specify what to congeal
sub get_game_phase_data : Private{ #for game.tt
   my ($self, $c) = @_;
   my ($game, $rulemap) = @{$c->stash}{qw/game rulemap/};
   
   my @p2g = $game->search_related( 'player_to_game',
      {},
      {
         join => 'player',
         '+select' => ['player.name'],
         '+as'     => ['name'],
         order_by => 'entity ASC',
      }
   );
   my @phases = $game->phases;
   my @fin = split ' ', $game->fin;
   my @caps = split ' ', $game->captures;
   
   my @phasedata;
   for my $phase (@phases){
      my $phasenum = scalar @phasedata;
      my ($ent,$side) = @$phase;
      my $p = $p2g[$ent];
      push @phasedata, { #this stuff sent to template.
         num => $phasenum,
         side => $side,
         playerid => $p->pid,
         playername => $p->get_column('name'),
         fin => $fin[$phasenum],
         captures => $caps[$phasenum],
         active => $game->phase == $phasenum,
      };
   }
   $c->stash->{phase_data} = \@phasedata;
}


#TODO: for a particular game/move?
sub json_board_pos :Private{
   my ($self, $c) = @_;
   my $board = $c->stash->{board}; #TODO: only get visible
   #TODO: send death_mask,territory_mask seperately
   my $json = to_json( $board );
   return $json
}
sub json_initial_board :Private{
   my ($self, $c) = @_;
   my $game = $c->stash->{game}; #TODO: only get visible
   #TODO: send death_mask,territory_mask seperately
   my $json = to_json( $game->initial_board );
   return $json
}


#this is called by tests.
sub allmoves : Chained('game') {
   my ( $self, $c) = @_;
   
   $c->forward ('get_game_moves');
   my $moves = $c->stash->{moves};
   
   $c->response->content_type ('text/json');
   $c->response->body (to_json (['success', $moves]));
   $c->detach;
}

#called by render and allmoves
sub get_game_moves : Private {
   my ( $self, $c) = @_;
   
   my $game = $c->stash->{game};
   my $pd = $c->stash->{ruleset}->phase_description;
   my @phases = map {[split '', $_]} split ' ', $pd;
   
   my @move_rows = $game->search_related ('moves',
      {},
      {
         select => ['movenum', 'phase', 'move'],
         order_by => 'movenum ASC' 
      }
   );
   my @moves;
   for my $mv_row (@move_rows){
      my $phase = $mv_row->phase;
      my $side = $phases[$phase][1];
      my $pretty_node; #a19, t1, etc. or whatever is visible in moves list
      if ($mv_row->move =~ /^\{(.*)\}$/){
         $pretty_node = $c->stash->{rulemap}->pretty_coordinates ($1);
      }
      else {
         $pretty_node = $mv_row->move;
      }
      push @moves, {
         movenum => $mv_row->movenum,
         side => $side,
         move => $mv_row->move,
         pretty_node => $pretty_node,
      }
   }
   $c->stash->{moves} = \@moves;
   $c->stash->{json_moves} = to_json (\@moves);
   $c->stash->{num_moves} = scalar @moves;
}



#also provide list of groups marked as dead
sub provide_all_chains : Private {
   my ($self, $c, $deads) = @_;
   $deads ||= '';
   my @deads = split '_', $deads; #from dead_groups format in db
   
   my ($game, $board, $rulemap) = @{$c->stash}{ qw/game board rulemap/ };
   my ($delegates, $delegate_of_stone, $delegate_side) = $rulemap->all_chains($board);
   
   $c->stash->{selecting_chains} = 1;
   #$c->stash->{json_chains} = to_json ([keys %$delegates]);
   #chains are the values of %$delegates
   $c->stash->{json_delegates} = to_json ($delegates);
   $c->stash->{json_delegate_of_stone} = to_json ($delegate_of_stone);
   $c->stash->{json_delegate_side} = to_json ($delegate_side);
   
   #initially. player can modify in page by clicking
   my %selected_chains = map {$_ => 0} keys %$delegate_side;
   #die @$deads;
   for (@deads){
      $selected_chains{$delegate_of_stone->{$_}} = 1;
   }
   $c->stash->{json_selected_chains} = to_json (\%selected_chains);
   
   $c->stash->{provide_chains} = 1
}


#for testing purposes
sub chains : Chained('game'){
   my ($self, $c) = @_;
   
   my ($game, $board, $rulemap) = @{$c->stash}{ qw/game board rulemap/ };
   my ($delegates, $delegate_of_stone, $delegate_side) = $rulemap->all_chains($board);
   
   my $res = {
      delegates => $delegates,
      delegate_of_stone => $delegate_of_stone,
      delegate_side => $delegate_side,
   };
   
   $c->response->content_type ('text/json');
   $c->response->body (to_json ($res));
   $c->detach
}

sub deltas : Chained('game') Args(0){
   my ($self, $c) = @_;
   my ($game, $board, $rulemap) = @{$c->stash}{ qw/game board rulemap/ };
   
   my $initial_board = $game->initial_board;
   my $initial_delta = $rulemap->initial_delta($initial_board);
   my @deltas = ($initial_delta);
   
   my @moves = $game->search_related ('moves',
      {},
      {
         join => 'position',
         order_by => 'movenum ASC',
         select => ['position', 'movenum'],
      }
   );
   my @positions = map {$_->get_column('position')} @moves;;
   my @boards = map {unpack_position ($_, $game->size)} @positions;
   unshift @boards, $initial_board; #throw in game's initial position
   
   for (1 .. @boards-1){
      push @deltas, $rulemap->delta (@boards[$_-1, $_]);
   }
   $c->response->content_type ('text/json');
   $c->response->body (to_json (\@deltas));
   $c->detach
}


1;
