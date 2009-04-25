package basilisk::Controller::Game;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use basilisk::Util;
use basilisk::Rulemap;
use JSON;




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
#and for cgi params: $c->stash->{caps, new_also_dead}

# /game/14/move/4-4
# /game/14/pass
# /game/14/dead/10-9/3-3_4-5_19-19 #or s/dead/alive/
sub game : Chained('/') CaptureArgs(1){ 
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
   my $board = Util::unpack_position($pos_data, $h, $w);
   @{$c->stash}{qw/old_pos_data board/} = ($pos_data, $board); #put board data in stash
   @{$c->stash}{qw/entity side/} = $game->turn; #phase data in stash
} #now c does chained actions:  move, pass, resign, think

sub render: Private{
   my ($self, $c) = @_;
   my ($rulemap, $board, $gameid) = @{$c->stash}{qw/rulemap board gameid/};
   #game's state may be altered:
   my $game = $c->stash->{game} = $c->model('DB::Game')->find ({'id' => $gameid});
   die 'wat' unless $game;
   my ($entity, $side) = $game->turn;
   
   unless ($c->stash->{board_clickable}){ #default: determine level of interaction with game
      if ($c->forward ('permission_to_move')){ #your turn
         $c->stash->{board_clickable} = 1;
         if ($c->forward('permission_to_mark_dead')){ #mark dead
            $c->stash->{marking_dead_stones} = 1;
            my ($deadgroups, $deathmask) = get_marked_dead_from_last_move ($c);
            if ($deadgroups){
               $c->stash->{new_also_dead} = $deadgroups;
               $c->stash->{death_mask} = $deathmask;
            }
            else { #start marking dead stones from nothing
               $c->stash->{new_also_dead} = '';
               $c->stash->{death_mask} = {};
            }
            my ($terr_mask, $terr_points) = $rulemap->find_territory_mask 
                           ($board, $deathmask);
            $c->stash->{territory_mask} = $terr_mask;
            $c->stash->{terr_points} = $terr_points;
         }
      }
      else {
         $c->stash->{board_clickable} = 0;
      }
   }
   if ($c->forward('permission_to_mark_dead')){
      $c->forward('prepare_group_json');
   }
   $c->stash->{show_dead_stones} = 1 if $c->stash->{death_mask}; # todo: or if game is over!
   if ($game->status == Util::FINISHED()){
      $c->stash->{show_dead_stones} = 1;
      my ($dg,$dm) = get_marked_dead_from_last_move ($c);
      $c->stash->{death_mask} = $dm;
   }
   
   if ($rulemap->topology eq 'C20'){
      $c->stash->{topo} = 'graph';
      $c->stash->{nodes} = $rulemap->all_node_coordinates;
      $c->stash->{edges} = $rulemap->node_adjacency_list;
      $c->stash->{stones} = $board;
   }
   else{ #grid
      $c->stash->{json_board_pos} = $c->forward('json_board_pos');
      $c->stash->{h} = $rulemap->h;
      $c->stash->{w} = $rulemap->w;
      $c->stash->{wrap_ns} = $rulemap->wrap_ns;
      $c->stash->{wrap_ew} = $rulemap->wrap_ew;
      $c->stash->{twist_ns} = $rulemap->twist_ns;
   }
   $c->forward ('get_game_phase_data');
   $c->stash->{game_running} = 1 if $game->status==Util::RUNNING();
   $c->stash->{title} = "Game " . $c->stash->{gameid}.", move " . $game->num_moves;
   
   $c->stash->{to_move_side} = $side;
   $c->stash->{to_move_player} = $c->stash->{game}->player_name_to_move_next;
   $c->stash->{result} = $game->result;
   $c->stash->{rules_description} = $c->stash->{ruleset}->rules_description;
   
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
   my $new_pos_data = Util::pack_board ($newboard, $h, $w);
   Util::ensure_position_size($new_pos_data, $h, $w); #sanity?
   
   
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
      $game->signal_fin_intent (Util::FIN_INTENT_FIN(), $pass_all);
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
      $game->signal_fin_intent (Util::FIN_INTENT_DROP(), $resign_all);
      $game->clear_fin_intent (); #this upsets the balance, so reset _FIN and _SCORED
      my $winner = $game->winner_by_resignation;
      if (defined $winner){
         $game->set_column ('status', Util::FINISHED());
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
   unless ($c->forward ('permission_to_move')){
      $c->stash->{msg} =  "permission fail: ".$c->stash->{whynot};
      $c->detach('render');
   }
   
   my $rulemap = $c->stash->{rulemap};
   my $game = $c->stash->{game};
   my $board = $c->stash->{board};
   my $think_all = 1; #always true....
   
   my ($entity, $side) = $game->turn;
   
   #not generic. do with rulemap.
   my @new_deads = map {[split'-',$_]} split '_', $deads;
   my $new_death_mask = $rulemap->death_mask_from_list($board, \@new_deads);
   
   my $prev_deads = $game->deads;
   my @old_deads = map {[split'-',$_]} split '_', $prev_deads;
   my $old_death_mask = $rulemap->death_mask_from_list($board, \@old_deads);
   
   my $equal_marks = $rulemap->compare_masks ($old_death_mask, $new_death_mask);
   my @new_death_list = $rulemap->death_mask_to_list($board, $new_death_mask);
   my $deadgroupsstring = join '_', map {join'-',@$_} @new_death_list;
   
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
      $game->signal_fin_intent (Util::FIN_INTENT_SCORED(), $think_all);
      my $done = $game->done_thinking;
      if ($done){ #game's over
         my $result = $rulemap->compute_score($board, $game->captures, $new_death_mask);
         $game->set_column ('status', Util::FINISHED());
         $game->set_column ('result', %$result);
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

#The following couple things are WRONG & UNUSED
#not a move. just update board in html: #/game/44/mark/dead/3-13
#this is to be done in js! so remove is TODO
sub mark_dead_or_alive : PathPart('mark') Chained('game') Args{
   my ($self, $c, $mark, $nodestring, $also_dead) = @_;
   die "no $mark" unless $mark eq 'dead' or $mark eq 'alive';
   
   unless ($c->forward('permission_to_mark_dead')){
      $c->stash->{msg} =  "permission fail: ".$c->stash->{whynot};
      $c->detach('render');
   }
   $c->stash->{marking_dead_stones} = 1;
   $c->stash->{board_clickable} = 1;
   
   my $rulemap = $c->stash->{rulemap};
   my $board = $c->stash->{board};
   my $mark_node = $rulemap->node_from_string ($nodestring);
   #my $also_dead = $c->req->param('also_dead');
   my @marked_dead_stones = map {[split'-',$_]} split '_', $also_dead;
   push @marked_dead_stones, $mark_node;
   my $death_mask = $rulemap->death_mask_from_list($board, \@marked_dead_stones);
   if ($mark eq 'alive'){
      $rulemap->mark_alive($board, $death_mask, $mark_node);
   }
   my $new_death_list = $rulemap->death_mask_to_list($board, $death_mask);
   
   $c->stash->{death_mask} = $death_mask;
   my ($terr_mask, $terr_points) = $rulemap->find_territory_mask ($board, $death_mask);
   $c->stash->{territory_mask} = $terr_mask;
   $c->stash->{terr_points} = $terr_points;
   # create string in url for cgi, in clickable board nodes
   $c->stash->{new_also_dead} = join '_', map{join'-',@$_} @$new_death_list;
   $c->forward('render');
}

#I guess this 'action' will be appended to the moves list.
#The move will point to the same position,
#and a string of dead groups is stored as the move text
#OR, if it's the same as the prev. score submission, the game is over.
sub action_submit_dead_selection: PathPart('submit_dead_selection') Chained('game'){ 
   my ($self, $c, $deadgroups) = @_;
   $deadgroups ||= '';
   unless ($c->forward('permission_to_mark_dead')){
      $c->stash->{msg} =  "permission fail: ".$c->stash->{whynot};
      $c->detach('render');
   }
   my $game = $c->stash->{game};
   
   #transaction!
   $c->model('DB')->schema->txn_do(  sub{
      my $moverow = $game->create_related( 'moves',
      {
         position_id => $game->current_position_id,
         move => 'submit_dead_selection',
         phase => $game->phase,
         movenum => $game->num_moves+1,
         time => time,
         dead_groups => $deadgroups,
         captures => $game->captures,
      });
      $game->shift_phase; #b to w, etc num_moves++
   });
   
   #Should game end now?
   my @prev_2_moves = $game->search_related ('moves', {}, {
      order_by=>'movenum DESC',
      rows => 2});
   #this is very much not generic!
   if (($prev_2_moves[0]->move eq 'submit_dead_selection')
     and ($prev_2_moves[1]->move eq 'submit_dead_selection')){
        if ($prev_2_moves[0]->dead_groups and $prev_2_moves[1]->dead_groups){
           $c->forward ('finish_game');
        }
        unless ($prev_2_moves[0]->dead_groups or $prev_2_moves[1]->dead_groups){
           $c->forward ('finish_game');
        }
   }
   $c->forward('render');
}
#to place a stone instead of scoring after 2+ passes:
sub wants_to_stop_scoring : PathPart('continue') Chained('game'){ 
   my ($self, $c) = @_;
   unless ($c->forward ('permission_to_move')){
      $c->stash->{msg} =  "permission fail: ".$c->stash->{whynot};
      $c->detach('render');
   }
   $c->stash->{board_clickable} = 1;
   $c->forward('render');
}


sub invalid_request : Private{
   my ($self, $c, $err) = @_;
   $c->stash->{message} = "Invalid request: $err";
   $c->stash->{template} = 'message.tt';
}


#sets $c->stash->{whynot} error. returns 1 if true
#TODO: handle surrogates! and set {surrogate} in stash!
sub permission_to_move : Private{
   my ($self, $c) = @_;
   
   $c->stash->{whynot} = '';
   $c->stash->{whynot} = 'not logged in' unless $c->session->{logged_in};
   return 0 if $c->stash->{whynot};
   #$c->stash->{whynot} = 'not registered' if $c->session->{userid} == 1;
   #return 0 if $c->stash->{whynot};
   
   my $game = $c->stash->{game};
   unless ($game->status == Util::RUNNING()){
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
   $c->stash->{side} = $side;
   return 1
}
#sets $c->stash->{whynot} error. returns 1 if true
sub permission_to_mark_dead : Private{
   my ($self, $c) = @_;
   return 0 unless ($c->forward ('permission_to_move'));
   #last 2 moves should be passes to start scoring process
   return 1 if $c->forward('last_move_was_score');
   return 1 if $c->forward('prev_p_moves_were_passes');
   return 0;
}
#replaced by fin?
sub last_move_was_score : Private{
   my ($self,$c) = @_;
   my $game = $c->stash->{game};
   my $nummoves = $game->num_moves;
   unless ($nummoves >= 3){ #impossible--require 2 pass moves + 1 score move
      $c->stash->{whynot} = 'You hound! You just started!';
      return 0;
   }
   my $prevmove = $game->moves->find ({movenum => $nummoves})->move;
   unless ($prevmove eq 'submit_dead_selection'){
      $c->stash->{whynot} = 'lastmove not score';
      return 0;
   }
   return 1;
}
#replaced by fin?
#returns explanation if no, '' if yes
sub prev_p_moves_were_passes : Private { #p=2players
   my ($self,$c) = @_;
   my $game = $c->stash->{game};
   my $nummoves = $game->num_moves;
   unless ($nummoves >= 2){
      $c->stash->{whynot} = 'You hound! You just started!';
      return 0}
   unless ($game->moves->find ({movenum => $nummoves})->move eq 'pass'){
      $c->stash->{whynot} = 'lastmove not pass';
      return 0}
   unless ($game->moves->find ({movenum => $nummoves-1})->move eq 'pass'){
      $c->stash->{whynot} = '2nd-to-lastmove not pass';
      return 0}
   return 1;
}
sub get_marked_dead_from_last_move{ #returns mask,stringofgroups
   my $c = shift;
   my $rulemap = $c->stash->{rulemap};
   my $game = $c->stash->{game};
   my $board = $c->stash->{board};
   my $last_move = $c->stash->{game}->last_move;   
    return unless $last_move;
   my $dead_groups = $last_move->dead_groups;
    return unless $dead_groups;
   # convert to list of nodes:
   my @dlist = map {$rulemap->node_from_string($_)} (split '_',$dead_groups); 
   my $death_mask = $rulemap->death_mask_from_list ($board, \@dlist);
   return ($dead_groups, $death_mask);
}
#TODO: make score calc generic
sub finish_game : Private{ #This does not check permissions. it just wraps things up
   my ($self, $c) = @_;
   my $rulemap = $c->stash->{rulemap};
   my $game = $c->stash->{game};
   my $board = $c->stash->{board};
   my ($death_mask, $terr_mask, $terr_points);
   $death_mask = $c->stash->{death_mask};
   ($terr_mask, $terr_points) = $rulemap->find_territory_mask ($board, $death_mask);
   my $deads = $rulemap->count_deads($board, $death_mask);
   
   # scoremodes are 'ffa','team', ?other?
   # is this a bad system?
   my $result;
   my $scoremode = $rulemap->detect_basis; # ($pd)
   if ($scoremode eq 'ffa'){
      my @totalscore;
      for my $entity ($rulemap->all_entities){ #0,1,etc
         my $caps = $rulemap->captures_of_entity($entity, $game->captures);
         my $side = $rulemap->side_of_entity($entity);
         $totalscore[$entity] = $caps + $terr_points->{$side} - $deads->{$side};
         $totalscore[$entity] += 6.5 if $side eq 'w';
      }
      my $winning_entity = largest (@totalscore);
      $result = "b:$totalscore[0], w:$totalscore[1]"; #not generic
   }
   else{
      die 'scoremode neq ffa';
   }
   $game->set_column ('status', Util::FINISHED());
   $game->set_column ('result', $result);
   $game->update();
}
#index of largest in list
sub largest{my ($i,$g,$v)=(-1,-1,-1);for$i(0..$#_){next if!defined$_[$i];next if$_[$i]<$v;$v=$_[$i];$g=$i}return$i}

#key of largest in hash
sub hashlargest{my%h=@_;my ($i,$g,$v)=(-1,-1,-1);for$i(keys%h){next if!defined$h{$i};next if$h{$i}<$v;$v=$h{$i};$g=$i}return$i}

sub build_rulemap : Private{
   my ($self, $c) = @_;
   my $game = $c->stash->{game};
   my $ruleset = $game->ruleset;
   my $pd = $ruleset->phase_description;
   my $topo = 'plane';
   my @extra_rules = $ruleset->extra_rules;
   my @extra_roles;
   for my $rulerow (@extra_rules){
      my $rule = $rulerow->rule;
      if (grep {$rule eq $_} @Util::acceptable_topo){
         $topo = $rule;
      }
      elsif ($rule =~ /^heisengo/){
         push @extra_roles, $rule;
      }
   }
   my $rulemap = new basilisk::Rulemap::Rect(
      h => $game->h,
      w => $game->w,
      wrap_ew => ($topo eq 'torus' or $topo eq 'cylinder' or $topo eq 'klein') ?1:0,
      wrap_ns => ($topo eq 'torus') ?1:0,
      twist_ew => 0,
      twist_ns => ($topo eq 'klein' or $topo eq 'mobius') ?1:0,
      topology => $topo,
      phase_description => $pd,
   );
   for (@extra_roles){
      $rulemap->apply_rule_role ($_);
   }
   $c->stash->{rulemap} = $rulemap;
}


sub detect_duplicate_position{
   my ($c, $newboard) = @_;
   my $game = $c->stash->{game};
   my $h = $game->h;
   my $w = $game->w;
   my $newpos = Util::pack_board($newboard, $h, $w);
   
   #search position table for the same board state from the same game
   my $oldmove = $game->find_related ( 'moves',
     {
      'position.position' => $newpos,
     },{
      'join' => 'position',
      '+select' => [ 'position.position'],
      '+as'     => [ 'oldpos' ],
   });
   $c->stash->{oldmove} = $oldmove;
   return 1 if $oldmove;
}

#this wraps the rulemap method to set stash values and detect ko
sub evaluate_move : Private{
   my ($self, $c, $node, $board) = @_;
   my $side = $c->stash->{side};
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
#TODO: congeal here, or specify what to congeal
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


#really client should do this drawing stuff
sub select_g_file{ #only for rect board
   my ($rulemap, $board, $row, $col) = @_;
   my $stone = $board->[$row][$col];
   return "$stone.gif" if $stone =~ /^[bwr]$/;
   #so it's an empty intersection
   return $rulemap->node_is_on_edge($row, $col) . '.gif';
}

my @cletters = qw/a b c d e f g h j k l m n o p q r s t u v w x y z/;

sub column_letter{
   my $c = shift;
   return $cletters[$c]
}

sub most_recent_move : Private{
   my ($self, $c) = @_;
   my $game = $c->stash->{game};
   my $mv = $game->find_related ('moves',
      {}, {order_by => 'movenum DESC'} );
   return $mv;
}

sub allmoves : Chained('game') {
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
   
   $c->response->content_type ('text/json');
   $c->response->body (to_json (['success', \@moves]));
}

sub prepare_group_json : Private {
   my ( $self, $c) = @_;
   my ($game, $board, $rulemap, $initially_dead) = @{$c->stash}{ qw/game board rulemap new_also_dead/ };
   my ($all_groups, $all_nodestrings, $group_sides) = $rulemap->all_chains($board);
   
   $c->stash->{selecting_groups} = 1;
   $c->stash->{json_groups} = to_json ($all_groups);
   $c->stash->{json_group_of_node} = to_json ($all_nodestrings);
   $c->stash->{json_group_side} = to_json ($group_sides);
   $c->stash->{json_group_selected} = to_json ({});
}

1;
