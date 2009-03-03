package basilisk::Controller::Game;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use basilisk::Util;
use basilisk::Rulemap;

__PACKAGE__->config->{namespace} = '';

#Note: death_mask and territory_mask should not be stored in the database.
# what you need to get them is a list of dead groups.

#all these actions may affect the view depending on which of these it sets:
# $c->stash->{board_clickable}
# $c->stash->{marking_dead_stones}
# $c->stash->{territory_mask}
# $c->stash->{death_mask}
#and for cgi params: $c->stash->{caps, new_also_dead}

#TODO: Does this have to suck so much?
#TODO: Can this be made generic?

# /game/14?action=move&co=4-4
# /game/14?action=pass
# /game/14?action=action=mark_dead&co=10-9&also_dead=3-3_4-5_19-19 #or action=mark_alive
#co=(row)-(col) starting at top-left
sub game : Global { 
   my ( $self, $c ) = @_;
   #extract game id from path
   my ($gameid) = $c->req->path =~ m|game/(\d*)|;
   
   unless ($gameid ){
      $c->stash->{message} = 'invalid request: please supply a game id';
      $c->stash->{template} = 'message.tt';return;
   }
   $c->stash->{gameid} = $gameid;
   my $game = $c->model('DB::Game')->find ({'id' => $gameid}, {cache => 1});
   $c->stash->{game} = $game;
   unless ($game){
      $c->stash->{message} = 'invalid request: no game with that id';
      $c->stash->{template} = 'message.tt';return;
   }
   $c->stash->{ruleset} = $game->ruleset;
   build_rulemap($c);
   
   my $pos_data = $game->current_position;
   my $size = $game->size;
   my $rulemap = $c->stash->{rulemap};
   my $board = Util::unpack_position($pos_data, $size);
   @{$c->stash}{qw/old_pos_data board/} = ($pos_data, $board); #put board data in stash
   
   #NEED DISPATCH
   #if $action and $action_dispatch{$action}{
   #   $action_dispatch{$action}->($c);
   #unless ($c->stash->{board_clickable})...
   my $action = $c->req->param('action');
   $action = '' unless $action;
   if ($action eq 'move'){ #evaluate & do move:
      my $err = seek_permission_to_move($c);
      if ($err){
         $c->stash->{message} = "permission fail: $err";
         $c->stash->{template} = 'message.tt'; return;
      }
      #extract coordinates from url: #TODO: make generic!
      ($c->stash->{move_row}, $c->stash->{move_col}) = split '-', $c->req->param('co');
      my ($newboard, $caps);
      ($err, $newboard, $caps) = evaluate_move($c);
      if ($err){
         $c->stash->{message} = "move is failure: $err";
         $c->stash->{template} = 'message.tt'; return;
      }
      #alter db
      do_move ($c, '', $newboard, $caps);
      $c->stash->{board} = $newboard;
      $c->stash->{msg} = 'move is success';
   }
   elsif ($action eq 'pass'){ #evaluate & do move:
      my $err = seek_permission_to_move($c);
      if ($err){
         $c->stash->{message} = "permission fail: $err";
         $c->stash->{template} = 'message.tt'; return;
      }
      #last 2 moves should be passes to start scoring process
      #my $dont_do_terr = prev_p_moves_were_passes($c);
      #unless ($dont_do_terr){
      #   my ($terr_mask, $points) = $rulemap->find_territory_mask ($board, {});
      #   $c->stash->{territory_mask} = $terr_mask;
      #}
      do_move ($c, 'pass');
      $c->stash->{board} = $board;
      $c->stash->{msg} = 'pass is success';
   }
   elsif ($action eq 'mark_dead' or $action eq 'mark_alive'){
      #not a move. just update board in html
      my $err = seek_permission_to_mark_dead($c);
      if ($err){
         $c->stash->{message} = "permission fail: $err";
         $c->stash->{template} = 'message.tt'; return;
      }
      $c->stash->{marking_dead_stones} = 1;
      $c->stash->{board_clickable} = 1;
      
      my $mark_co = [split '-', $c->req->param('co')];
      my $also_dead = $c->req->param('also_dead');
      my @marked_dead_stones = map {[split'-',$_]} split '_', $also_dead;
      push @marked_dead_stones, $mark_co;
      my $death_mask = $rulemap->death_mask_from_list($board, \@marked_dead_stones);
      if ($action eq 'mark_alive'){
         $rulemap->mark_alive($board, $death_mask, $mark_co);
      }
      my $new_death_list = $rulemap->death_mask_to_list($board, $death_mask);
      $c->stash->{death_mask} = $death_mask;
      my ($terr_mask, $terr_points) = $rulemap->find_territory_mask ($board, $death_mask);
      $c->stash->{territory_mask} = $terr_mask;
      $c->stash->{terr_points} = $terr_points;
      # create string in url for cgi, in clickable board nodes
      $c->stash->{new_also_dead} = join '_', map{join'-',@$_} @$new_death_list;
   }
   elsif ($action eq 'submit_dead_selection'){ 
      #I guess this will be appended to the moves list.
      #The move will point to the same position,
      #and a string of dead groups is stored as the move text
      #OR, if it's the same as the prev. score submission, the game is over.
      my $err = seek_permission_to_mark_dead($c);
      if ($err){
         $c->stash->{message} = "permission fail: $err";
         $c->stash->{template} = 'message.tt'; return;
      }
      my $deadstring = $c->req->param('dead_stones');
      do_move ($c, 'submit_dead_selection', undef, undef, $deadstring);
      #Should game end?
      my @prev_2_moves = $game->moves->search ({}, {
         order_by=>'movenum DESC',
         rows => 2});
      if ($prev_2_moves[1]->movestring eq 'submit_dead_selection'){
         if ($prev_2_moves[0]->dead_groups eq $prev_2_moves[1]->dead_groups){
            #so they agree on dead groups.
            finish_game($c);
         }
      }
   }
   elsif ($action eq 'continue'){ #place a stone instead of scoring after 2 passes+
      my $err = seek_permission_to_move($c);
      if ($err){
         $c->stash->{message} = "permission fail: $err";
         $c->stash->{template} = 'message.tt'; return;
      }
      $c->stash->{board_clickable} = 1;
   }
   unless ($c->stash->{board_clickable}){ #default: determine level of interaction with game
      my $err = seek_permission_to_move($c);
      unless ($err){ #your turn
         $c->stash->{board_clickable} = 1;
         $err = seek_permission_to_mark_dead($c);
         unless ($err){ #mark dead
            $c->stash->{marking_dead_stones} = 1;
            my ($deadgroups, $deathmask) = dead_from_last_move ($c);
            if ($deadgroups){
               $c->stash->{new_also_dead} = $deadgroups;
               $c->stash->{death_mask} = $deathmask;
               my ($terr_mask, $terr_points) = $rulemap->find_territory_mask ($board, $deathmask);
               $c->stash->{territory_mask} = $terr_mask;
               $c->stash->{terr_points} = $terr_points;
            }
            else { #start marking dead stones from nothing
               $c->stash->{new_also_dead} = '';
               $c->stash->{death_mask} = {};
               my ($terr_mask, $terr_points) = $rulemap->find_territory_mask ($board, {});
               $c->stash->{territory_mask} = $terr_mask;
               $c->stash->{terr_points} = $terr_points;
            }
         }
      }
   }
   $c->stash->{show_dead_stones} = 1 if $c->stash->{death_mask}; # todo: or if game is over!
   if ($game->status == Util::FINISHED()){
      $c->stash->{show_dead_stones} = 1;
      my ($dg,$dm) = dead_from_last_move ($c);
      $c->stash->{death_mask} = $dm;
   }
   render_board_table($c);
   
   $c->stash->{title} = "Game " . $c->stash->{gameid}.", move " . $game->num_moves;
   $c->stash->{players_data} = get_game_player_data($c);
   $c->stash->{to_move_img} = ($game->turn) == 1 ? 'b.gif' : 'w.gif';
   $c->stash->{result} = $game->result;
   $c->stash->{extra_rules_desc} = $c->stash->{ruleset}->rules_description;
   $c->stash->{c_letter} = \&column_letter;
   $c->stash->{template} = 'game.tt';
}

#returns error string if error. #TODO: these could return true, or set some stash error var
sub seek_permission_to_move{
   my $c = shift;
   return 'not logged in' unless $c->session->{logged_in};
   return 'not registered' if $c->session->{userid} == 1;
   my $game = $c->stash->{game};
   return 'Game is already finished!' unless $game->status == Util::RUNNING();
   my $p = $c->model('DB::player_to_game')->find( {
       gid => $game->id,
       side => $game->turn,
   });
   return "player on side ".$game->turn."not found for game ".$c->stash->{gameid}
      unless $p;
   return 'not your turn.' unless $c->session->{userid} == $p->pid;
   #success
   return 'strange' unless $game->turn == $p->side;
   $c->stash->{p2g} = $p;
   $c->stash->{side} = $p->side;
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
sub dead_from_last_move{ #returns mask,stringofgroups
   my $c = shift;
   my $game = $c->stash->{game};
   my $board = $c->stash->{board};
   my $last_move = $c->stash->{game}->last_move;   
    return unless $last_move;
   my $dead_groups = $last_move->dead_groups;
    return unless $dead_groups;
   #TODO: generic
   my @dlist = map {[split'-',$_]} (split '_',$dead_groups);# convert to node list 
   my $death_mask = $c->stash->{rulemap}->death_mask_from_list ($board, \@dlist);
   return ($dead_groups, $death_mask);
}
#TODO: make score calc generic
sub finish_game{ #This does not check permissions. it just wraps things up
   my $c = shift;
   my $rulemap = $c->stash->{rulemap};
   my $game = $c->stash->{game};
   my $board = $c->stash->{board};
   my ($caps, $kills, $terr_points); #all [1..2]. these add. kills are negative.
   my ($death_mask, $terr_mask);
   my @p2g = $game->player_to_game; #sides 1..2
   
   $death_mask = $c->stash->{death_mask};
   ($terr_mask, $terr_points) = $rulemap->find_territory_mask ($board, $death_mask);
   $kills = $rulemap->count_kills($board, $death_mask);
   my @totalscore;
   for (@p2g){
      my $side = $_->side;
      #die ref $_->side if ref $side eq 'ARRAY';
      $caps->[$side] = $_->captures;
      $totalscore[$side] = $caps->[$side] + $terr_points->[$side] - $kills->[$side];
   }
   $totalscore[2] += 6.5;
   my $winning_side = largest (@totalscore);
   #die $totalscore[1];$winning_side;
   my $result = "b:$totalscore[1], w:$totalscore[2]";
   $game->set_column ('status', Util::FINISHED());
   $game->set_column ('result', $result);
   $game->update();
}
#index of largest in list
sub largest{my ($i,$g,$v)=(0,0,-555);for$i(0..$#_){next if$_[$i]<$v;$v=$_[$i];$g=$i}return$i}

sub build_rulemap{
   my $c = shift;
   my $game = $c->stash->{game};
   my $ruleset = $game->ruleset;
   my $topo = 'plane';
   my @extra_rules = $ruleset->extra_rules;
   for my $rulerow (@extra_rules){
      my $rule = $rulerow->rule;
      if ($rule eq 'torus' or $rule eq 'cylinder'){
         $topo = $rule;
      }
   }
   my $rulemap = new basilisk::Rulemap(
      size => $game->size,
      topology => $topo,
   );
   $c->stash->{rulemap} = $rulemap;
}


sub detect_duplicate_position{
   my ($c, $newboard) = @_;
   my $size = $c->stash->{game}->size;
   my $newpos = Util::pack_board($newboard, $size);
   
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
   my ($row, $col, $board) = @{$c->stash}{qw/move_row move_col board/};
   my $turn = $c->stash->{game}->turn; #turn==color, right?
   
   #find next board position:
   my ($newboard, $err, $caps) = $c->stash->{rulemap}->evaluate_move
         ($board,$row,$col,$turn);
   return $err unless $newboard;
   if (detect_duplicate_position($c, $newboard)){
      return 'Ko error: this is a repeating position from move '.$c->stash->{oldmove}->movenum
   }
   return ('',$newboard, $caps);#no err
}
#die join';',map{@$_}@$libs; #err list of coordinates

#insert into db
#TODO: make generic
sub do_move{#todo:mv to game class?
   my ($c, $movestring, $newboard, $caps, $deadgroups) = @_;
   my $new_pos_data;
   my $game = $c->stash->{game}; #die $game->num_moves;
   my $side = $c->stash->{side}; #1 if B,2 if W
   my $size = $game->size;
   my $posid; #maybe we reuse last one
   
   #determine move string and new position
   if ($movestring eq 'pass'){
      $new_pos_data = $c->stash->{old_pos_data};
      Util::ensure_position_size($new_pos_data, $size); #sanity?
   }
   elsif ($movestring eq 'submit_dead_selection'){ #we reuse last position
      $posid = $game->current_position_id;
   }
   else { # it eq ''
      my ($row, $col) = ($c->stash->{move_row}, $c->stash->{move_col});
      $movestring = ($side==1?'b':'w') . " row$row, col$col";
      $new_pos_data = Util::pack_board($newboard, $size);
      Util::ensure_position_size($new_pos_data, $size); #sanity?
   }
   
   #transaction!
   $c->model('DB')->schema->txn_do(  sub{
      die 'Check whether game is finished before do_move!' unless $game->status == Util::RUNNING();
      if ($caps and @$caps){ #update capture count
         my $p2g = $c->stash->{p2g};#player_to_game
         $p2g->set_column('captures',$p2g->captures + @$caps); #INT
         $p2g->update;
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
      $game->shift_turn; #b to w, etc num_moves++
   });
   return;
}

sub get_game_player_data{ #for game.tt
   my ($c) = @_;
   my @lines;
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
   for my $p (@players){
      #todo: calc time remaining, render human readable
      my $img = ($p->side==1 ? 'b' : 'w') . '.gif';
      push @playerdata, {
         side => $p->side,
         stone_img => $img,
         name => $p->get_column('name'),
         id => $p->pid,
         time_remaining => $p->expiration,
         captures => $p->captures,
      };
   }
   my $terr_points = $c->stash->{terr_points};
   if ($terr_points){ #set territory point display
      for my $i (1..@$terr_points-1){ #terr_points starts at 1.
         $playerdata[$i-1]{captures} .= ' (+'. $terr_points->[$i].') (+ foo)'; #+marked caps
      }
   }
   return \@playerdata;
}

#todo: move url param stuff into tt
sub render_board_table{
   my ($c) = @_;
   my $size = $c->stash->{game}->size;
   my $board = $c->stash->{board};
   my $rulemap = $c->stash->{rulemap};
   my $death_mask = $c->stash->{death_mask};
   my $terr_mask = $c->stash->{territory_mask};
   $terr_mask = {} unless $terr_mask;
   my @table; #html cells representing nodes
   
   for my $row (0..$size-1){
      for my $col (0..$size-1){ #get image and url for table cell
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
               $image =~ s/\.gif/b\.gif/ if $terr==1;
               $image =~ s/\.gif/w\.gif/ if $terr==2;
            }
         }
         $table[$row][$col]->{g} = $image;
         #url if applicable:
         if ($c->stash->{board_clickable}) {
            if ($stone==0){ #empty intersection
               unless ($c->stash->{marking_dead_stones}){ #can't move when marking dead
                  my $url = "game/".$c->stash->{gameid} . "?action=move&co=" . $row .'-'.$col;
                  $table[$row][$col]->{ref} = $url;
               }
            }
            elsif ($c->stash->{marking_dead_stones}){ #stone here
               my $mark = $death_mask->{$row.'-'.$col} ? 'alive' : 'dead'; #have clicker flip stone status
               my $url = "game/".$c->stash->{gameid} . "?action=mark_$mark&co=" . $row .'-'.$col;
               $url .= "&also_dead=" . $c->stash->{new_also_dead};
               $table[$row][$col]->{ref} = $url;
            }
         }
      }
   }
   $c->stash->{board_data} = \@table;
}

sub select_g_file{ #default board
   my ($rulemap, $board, $row, $col) = @_;
   my $stone = $board->[$row][$col];
   return 'b.gif' if $stone == 1;
   return 'w.gif' if $stone == 2;
   #so it's an empty intersection
   return $rulemap->grid_node_is_on_edge($row, $col) . '.gif';
}

my @cletters = qw/a b c d e f g h j k l m n o p q r s t u v w x y z/;

sub column_letter{
   my $c = shift;
   return $cletters[$c]
}

1;
