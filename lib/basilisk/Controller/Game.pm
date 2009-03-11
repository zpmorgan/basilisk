package basilisk::Controller::Game;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use basilisk::Util;
use basilisk::Rulemap;

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
      $c->go ('invalid_request', ['no game with that id']);
   }
   $c->stash->{ruleset} = $game->ruleset;
   build_rulemap($c);
   
   my $pos_data = $game->current_position;
   my $h = $game->h;
   my $w = $game->w;
   my $rulemap = $c->stash->{rulemap};
   my $board = Util::unpack_position($pos_data, $h, $w);
   @{$c->stash}{qw/old_pos_data board/} = ($pos_data, $board); #put board data in stash
   @{$c->stash}{qw/entity side/} = $game->turn; #phase data in stash
} #dow c does move, etc

sub render: Private{
   my ($self, $c) = @_;
   my ($rulemap, $board, $game) = @{$c->stash}{qw/rulemap board game/};
   
   unless ($c->stash->{board_clickable}){ #default: determine level of interaction with game
      my $err = seek_permission_to_move($c);
      unless ($err){ #your turn
         $c->stash->{board_clickable} = 1;
         $err = seek_permission_to_mark_dead($c);
         unless ($err){ #mark dead
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
      render_board_table($c);
   }
   $c->stash->{title} = "Game " . $c->stash->{gameid}.", move " . $game->num_moves;
   $c->stash->{players_data} = get_game_player_data($c);
   $c->stash->{to_move_img} = ($c->stash->{side} eq 'b') ? 'b.gif' : 'w.gif';
   $c->stash->{result} = $game->result;
   $c->stash->{extra_rules_desc} = $c->stash->{ruleset}->rules_description;
   $c->stash->{c_letter} = \&column_letter;
   $c->stash->{template} = 'game.tt';
}# now goes to template

#view this game
sub view : Chained('game') {
   my ($self, $c) = @_;
   $c->forward('render');
}

sub move : Chained('game') Args(1){ #evaluate & do move:
   my ($self, $c, $nodestring) = @_;
   my $err = seek_permission_to_move($c);
   if ($err){
      action_abort ($c, "permission fail: $err");
      return;
   }
   #extract coordinates from url:
   $c->stash->{move_node} = $c->stash->{rulemap}->node_from_string ($nodestring);
   my ($err2, $newboard, $caps) = evaluate_move($c);
   if ($err2){
      action_abort ($c, "move is failure: $err2");
      return;
   }
   #alter db
   do_move ($c, '', $newboard, $caps);
   $c->stash->{board} = $newboard;
   $c->stash->{msg} = 'move is success';
   $c->forward('render');
}
sub pass : Chained('game') { #evaluate & do pass: Args(0)
   my ($self, $c) = @_;
   my $err = seek_permission_to_move($c);
   if ($err){
      action_abort ($c, "permission fail: $err");
      return;
   }
   do_move ($c, 'pass');
   #$c->stash->{board} = $board; #ALREADY_IN_STASH
   $c->stash->{msg} = 'pass is success';
   $c->forward('render');
}

#not a move. just update board in html: #/game/44/mark/dead/3-13
sub mark_dead_or_alive : PathPart('mark') Chained('game') Args{
   my ($self, $c, $mark, $nodestring, $also_dead) = @_;
   die "no $mark" unless $mark eq 'dead' or $mark eq 'alive';
   
   my $err = seek_permission_to_mark_dead($c);
   if ($err){
      action_abort ($c, "permission fail: $err");
      return;
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
sub action_submit_dead_selection: PathPart('submit') Chained('game'){ 
   my ($self, $c, $deadstring) = @_;
   $deadstring ||= '';
   my $err = seek_permission_to_mark_dead($c);
   if ($err){
      action_abort ($c, "permission fail: $err");
      $c->detach('render')
   }
   my $game = $c->stash->{game};
   do_move ($c, 'submit_dead_selection', undef, undef, $deadstring);
   #Should game end?
   my @prev_2_moves = $game->moves->search ({}, {
      order_by=>'movenum DESC',
      rows => 2});
   #this is very much not generic!
   if (($prev_2_moves[0]->movestring eq 'submit_dead_selection')
     and ($prev_2_moves[1]->movestring eq 'submit_dead_selection')){
        if ($prev_2_moves[0]->dead_groups and $prev_2_moves[1]->dead_groups){
           finish_game($c);
        }
        unless ($prev_2_moves[0]->dead_groups or $prev_2_moves[1]->dead_groups){
           finish_game($c);
        }
   }
   else {
      $c->stash->{msg} = $prev_2_moves[0]->movestring . '<br>' .
                        $prev_2_moves[0]->dead_groups . '<br>' .
                        $prev_2_moves[1]->movestring . '<br>' .
                        $prev_2_moves[1]->dead_groups ;
                     }
   $c->forward('render');
}
#to place a stone instead of scoring after 2+ passes:
sub wants_to_stop_scoring : PathPart('continue') Chained('game'){ 
   my ($self, $c) = @_;
   my $err = seek_permission_to_move($c);
   if ($err){
      action_abort ($c, "permission fail: $err");
      return;
   }
   $c->stash->{board_clickable} = 1;
   $c->forward('render');
}

sub invalid_request : Private{
   my ($self, $c, $err) = @_;
   $c->stash->{message} = "Invalid request: $err";
   $c->stash->{template} = 'message.tt';
}

sub action_abort{ #not an action. this aborts the action.
   my ($c, $err) = @_;
   $c->stash->{msg} = $err;
   #$c->stash->{template} = 'message.tt';
   $c->detach('render')
}

#returns error string if error. #TODO: these could return true, or set some stash error var
sub seek_permission_to_move{
   my $c = shift;
   return 'not logged in' unless $c->session->{logged_in};
   return 'not registered' if $c->session->{userid} == 1;
   my $game = $c->stash->{game};
   return 'Game is already finished!' unless $game->status == Util::RUNNING();
   
   my ($entity, $side) = $game->turn;
   my $gid = $game->id;
   my $p = $c->model('DB::player_to_game')->find( {
       gid => $gid,
       entity => $entity,
   }); 
   return "entity $entity not found for game $gid" unless $p;
   return 'not your turn.' unless $c->session->{userid} == $p->pid;
   #success
   #return 'strange' unless $entity == $p->entity;
   $c->stash->{p2g} = $p;
   $c->stash->{entity} = $entity;
   $c->stash->{side} = $side;
   return ''
}
   
sub seek_permission_to_mark_dead{ #returns err if err
   my $c = shift;
   my $err = seek_permission_to_move($c);
   return $err if $err;
   #last 2 moves should be passes to start scoring process
   $err = last_move_was_score($c);
   return '' unless $err;
   $err = prev_p_moves_were_passes($c);
   return $err
}
sub last_move_was_score{
   my $c = shift;
   my $game = $c->stash->{game};
   my $nummoves = $game->num_moves;
   return 'You hound! You just started!' unless $nummoves >= 3;
   my $prevmovestring = $game->moves->find ({movenum => $nummoves})->movestring;
   return 'lastmove not score' unless $prevmovestring eq 'submit_dead_selection';
   return '';
}
#returns explanation if no, '' if yes
sub prev_p_moves_were_passes { #p=2players
   my $c = shift;
   my $game = $c->stash->{game};
   my $nummoves = $game->num_moves;
   return 'You hound! You just started!' unless $nummoves >= 2;
   return 'lastmove not pass' unless $game->moves->find ({movenum => $nummoves})->movestring eq 'pass';
   return '2nd-to-lastmove not pass' unless $game->moves->find ({movenum => $nummoves-1})->movestring eq 'pass';
   return '';
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
sub finish_game{ #This does not check permissions. it just wraps things up
   my $c = shift;
   my $rulemap = $c->stash->{rulemap};
   my $game = $c->stash->{game};
   my $board = $c->stash->{board};
   my ($caps, $kills, $terr_points); #all {b,w,r}. these add. kills are negative.
   my ($death_mask, $terr_mask);
   $death_mask = $c->stash->{death_mask};
   ($terr_mask, $terr_points) = $rulemap->find_territory_mask ($board, $death_mask);
   $kills = $rulemap->count_kills($board, $death_mask);
   $caps = $game->captures_per_side;
   
   my %totalscore; #{b,w,r}
   my @sides = $game->sides;
   for (0..@sides-1){
      my $side = $sides[$_];
      $totalscore{$side} = $caps->{$side} + $terr_points->{$side} - $kills->{$side};
   }
   $totalscore{'w'} += 6.5;#bad
   my $winning_side = hashlargest (%totalscore);
   my $result = "b:$totalscore{b}, w:$totalscore{w}";
   $game->set_column ('status', Util::FINISHED());
   $game->set_column ('result', $result);
   $game->update();
}
#index of largest in list
sub largest{my ($i,$g,$v)=(-1,-1,-1);for$i(0..$#_){next if!defined$_[$i];next if$_[$i]<$v;$v=$_[$i];$g=$i}return$i}

#key of largest in hash
sub hashlargest{my%h=@_;my ($i,$g,$v)=(-1,-1,-1);for$i(keys%h){next if!defined$h{$i};next if$h{$i}<$v;$v=$h{$i};$g=$i}return$i}

sub build_rulemap{
   my $c = shift;
   my $game = $c->stash->{game};
   my $ruleset = $game->ruleset;
   my $topo = 'plane';
   my @extra_rules = $ruleset->extra_rules;
   for my $rulerow (@extra_rules){
      my $rule = $rulerow->rule;
      if ($rule eq 'torus' or $rule eq 'cylinder' or $rule eq 'C20'){
         $topo = $rule;
      }
   }
   my $rulemap = new basilisk::Rulemap::Rect(
      h => $game->h,
      w => $game->w,
      wrap_ew => ($topo eq 'torus' or $topo eq 'cylinder'),
      wrap_ns => ($topo eq 'torus'),
      #topology => $topo,
   );
   $c->stash->{rulemap} = $rulemap;
}


sub detect_duplicate_position{
   my ($c, $newboard) = @_;
   my $h = $c->stash->{game}->h;
   my $w = $c->stash->{game}->w;
   my $newpos = Util::pack_board($newboard, $h, $w);
   
   #search position table for the same board state from the same game
   my $oldmove = $c->model('DB::Move')->find (
     {
      gid => $c->stash->{game}->id,
      'position.position' => $newpos,
     },{
      'join' => 'position',
      '+select' => [ 'position.position'],
      '+as'     => [ 'oldpos' ],
   });
   $c->stash->{oldmove} = $oldmove;
   return 1 if $oldmove;
}

sub evaluate_move{
   my $c = shift;
   my ($node, $board) = @{$c->stash}{qw/move_node board/};
   my $side = $c->stash->{side};
   die $side unless $side =~ /^[bwr]$/;
   #find next board position:
   my ($newboard, $err, $caps) = $c->stash->{rulemap}->evaluate_move
         ($board,$node,$side);
   return $err unless $newboard;
   if (detect_duplicate_position($c, $newboard)){
      return 'Ko error: this is a repeating position from move '.$c->stash->{oldmove}->movenum
   }
   return ('',$newboard, $caps);#no err
}
#die join';',map{@$_}@$libs; #err list of coordinates

#insert into db
sub do_move{#todo:mv to game class?
   my ($c, $movestring, $newboard, $caps, $deadgroups) = @_;
   my $new_pos_data;
   my $game = $c->stash->{game}; #die $game->num_moves;
   my $side = $c->stash->{side}; #1 if B,2 if W
   my $h = $c->stash->{game}->h;
   my $w = $c->stash->{game}->w;
   my $posid; #maybe we reuse last one
   
   #determine move string and new position
   if ($movestring eq 'pass'){
      $new_pos_data = $c->stash->{old_pos_data};
      Util::ensure_position_size($new_pos_data, $h, $w); #sanity?
   }
   elsif ($movestring eq 'submit_dead_selection'){ #we reuse last position
      $posid = $game->current_position_id;
   }
   else { # it eq ''
      my ($row, $col) = @{$c->stash->{move_node}};
      $movestring = "$side row$row, col$col";
      $new_pos_data = Util::pack_board($newboard, $h, $w);
      Util::ensure_position_size($new_pos_data, $h, $w); #sanity?
   }
   
   #transaction!
   $c->model('DB')->schema->txn_do(  sub{
      die 'Check whether game is finished before do_move!' unless $game->status == Util::RUNNING();
      if ($caps and @$caps){ #update capture count
         my @all_caps = split ' ', $game->captures;
         $all_caps [$game->phase] += @$caps;
         $game->set_column('captures', join ' ', @all_caps); #INT
         $game->update;
      }
      unless ($posid){
         my $posrow = $c->model('DB::Position')->create( {
            ruleset => $c->stash->{ruleset}->id,
            position => $new_pos_data,
         });
         $posid = $posrow->id;
      }
      my $moverow = $c->model('DB::Move')->create( {
         gid => $game->id,
         position_id => $posid,
         movestring => $movestring,
         movenum => $game->num_moves+1,
         time => time,
         dead_groups => $deadgroups,
      });
      $game->shift_phase; #b to w, etc num_moves++
   });
   return;
}

sub get_game_player_data{ #for game.tt
   my ($c) = @_;
   my $game = $c->stash->{game};
   #get player-game data
   my @players = $c->model('DB::Player_to_game')->search( 
      {gid => $c->stash->{gameid}},
      {join => 'player',
         '+select' => ['player.name'],
         '+as'     => ['name']
      }
   );
   my @playerdata;
   #put data in hashes in @playerdata for template
   my $caps = $game->captures_per_side;
   for my $p (@players){
      #todo: calc time remaining, render human readable
      my $side = $game->side_of_entity($p->entity);
      my $img = $side . '.gif';
      push @playerdata, {
         entity => $p->entity,
         stone_img => $img,
         name => $p->get_column('name'),
         id => $p->pid,
         time_remaining => $p->expiration,
         captures => $caps->{$side},
      };
   }
   return \@playerdata;
}

sub get_score_data{
   my ($c) = @_;
   my @score_data;
   my $terr_points = $c->stash->{terr_points};
   if ($terr_points){ #set territory point display
      #kills are negative.
      my $rulemap = $c->stash->{rulemap};
      my $kills = $rulemap->count_kills($c->stash->{board}, $c->stash->{death_mask});
      for my $i (1..@$terr_points-1){ #terr_points starts at 1.
         $score_data[$i-1]{captures} .= ' (+'. $terr_points->[$i].') (- '.$kills->[$i].')'; #+marked caps
      }
   }
   
}

#todo: move url param stuff into tt
sub render_board_table{
   my ($c) = @_;
   my $h = $c->stash->{game}->h;
   my $w = $c->stash->{game}->w;
   my $board = $c->stash->{board};
   my $rulemap = $c->stash->{rulemap};
   my $death_mask = $c->stash->{death_mask};
   my $terr_mask = $c->stash->{territory_mask};
   $terr_mask = {} unless $terr_mask;
   my @table; #html cells representing nodes
   
   #TODO: each board type needs a template.
   #This one could be in templates/game/rectgrid.tt
   for my $row (0..$h-1){
      for my $col (0..$w-1){ #get image and url for table cell
         my $image = select_g_file ($rulemap, $board, $row, $col);
         my $stone = $board->[$row]->[$col]; #0 if empty, 1 b, 2 w
         my $terr = $terr_mask->{$row.'-'.$col}; #0 if empty, 1 b, 2 w
         my $dead = $death_mask->{$row.'-'.$col};
         if ($stone){
            if ($dead){ #replace with 'dead gfx'
               $image =~ s/^b\.gif/bw.gif/;
               $image =~ s/^w\.gif/wb.gif/;
            }
         }
         else {#no stone
            if ($terr) { #territory
               $image =~ s/\.gif/b\.gif/ if $terr eq 'b';
               $image =~ s/\.gif/w\.gif/ if $terr eq 'w';
            }
         }
         $table[$row][$col]->{g} = $image;
         #url if applicable:
         if ($c->stash->{board_clickable}) {
            unless ($stone){ #empty intersection
               unless ($c->stash->{marking_dead_stones}){ #can't move when marking dead
                  my $url = "game/".$c->stash->{gameid} . "/move/" . $row .'-'.$col;
                  $table[$row][$col]->{ref} = $url;
               }
            }
            elsif ($c->stash->{marking_dead_stones}){ #stone here
               my $mark = $death_mask->{$row.'-'.$col} ? 'alive' : 'dead'; #have clicker flip stone status
               my $url = "game/".$c->stash->{gameid} . "/mark/$mark/" . $row .'-'.$col;
               $url .= "/" . $c->stash->{new_also_dead};
               $table[$row][$col]->{ref} = $url;
            }
         }
      }
   }
   $c->stash->{board_data} = \@table;
   $c->stash->{h} = $h;
   $c->stash->{w} = $w;
}

sub select_g_file{ #only for rect board
   my ($rulemap, $board, $row, $col) = @_;
   my $stone = $board->[$row][$col];
   return 'b.gif' if $stone eq 'b';
   return 'w.gif' if $stone eq 'w';
   #so it's an empty intersection
   return $rulemap->node_is_on_edge($row, $col) . '.gif';
}

my @cletters = qw/a b c d e f g h j k l m n o p q r s t u v w x y z/;

sub column_letter{
   my $c = shift;
   return $cletters[$c]
}

1;
