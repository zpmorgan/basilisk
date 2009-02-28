package basilisk::Controller::Game;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use basilisk::Util;
use basilisk::Rulemap;

__PACKAGE__->config->{namespace} = '';

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
   $c->stash->{game} = $c->model('DB::Game')->find ({'id' => $gameid});
   unless ($c->stash->{game}){
      $c->stash->{message} = 'invalid request: no game with that id';
      $c->stash->{template} = 'message.tt';return;
   }
   $c->stash->{ruleset} = $c->stash->{game}->ruleset;
   build_rulemap($c);
   
   my $pos_data = $c->stash->{game}->current_position;
   my $size = $c->stash->{game}->size;
   my $rulemap = $c->stash->{rulemap};
   my $board = Util::unpack_position($pos_data, $size);
   @{$c->stash}{qw/old_pos_data board/} = ($pos_data, $board); #put board data in stash
   
   my $action = $c->req->param('action');
   $action = '' unless $action;
   if ($action eq 'move'){ #evaluate & do move:
      my $err = seek_permission_to_move($c);
      if ($err){
         $c->stash->{message} = "permission fail: $err";
         $c->stash->{template} = 'message.tt'; return;
      }
      
      #extract coordinates from url:
      ($c->stash->{move_row}, $c->stash->{move_col}) = split '-', $c->req->param('co');
      my ($newboard, $caps);
      ($err, $newboard, $caps) = evaluate_move($c);
      if ($err){
         $c->stash->{message} = "move is failure: $err";
         $c->stash->{template} = 'message.tt'; return;
      }
      else { #alter db
         #do_move($c, $newboard);
         do_move ($c, '', $newboard, $caps);
         $c->stash->{board} = $newboard;
         $c->stash->{msg} = 'move is success';
      }
   }
   elsif ($action eq 'pass'){ #evaluate & do move:
      my $err = seek_permission_to_move($c);
      if ($err){
         $c->stash->{message} = "permission fail: $err";
         $c->stash->{template} = 'message.tt'; return;
      }
      do_move ($c, 'pass');
      $c->stash->{board} = $board;
      $c->stash->{msg} = 'pass is success';
   }
   elsif ($action eq 'mark_dead' or $action eq 'mark_alive'){
      #not a move. just update board table
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
      my ($terr_mask, $caps) = $rulemap->find_territory_mask ($board, $death_mask);
      $c->stash->{territory_mask} = $terr_mask;
      $c->stash->{caps} = $caps;
      # create string in url for cgi, in clickable board nodes
      $c->stash->{new_also_dead} = join '_', map{join'-',@$_} @$new_death_list;
   }
   unless ($c->stash->{board_clickable}){ #determine level of interaction with game
      my $err = seek_permission_to_move($c);
      unless ($err){
         $c->stash->{board_clickable} = 1;
         $err = seek_permission_to_mark_dead($c);
         unless ($err){
            $c->stash->{marking_dead_stones} = 1;
            $c->stash->{new_also_dead} = '';
            $c->stash->{death_mask} = {};
         }
      }
   }
   $c->stash->{show_dead_stones} = 1 if $c->stash->{death_mask}; # todo: or if game is over!
   render_board_table($c);
   
   $c->stash->{title} = "Game " . $c->stash->{gameid}.", move " . $c->stash->{game}->num_moves;
   $c->stash->{players_data} = get_game_player_data($c);
   $c->stash->{to_move_img} = ($c->stash->{game}->turn) == 1 ? 'b.gif' : 'w.gif';
   $c->stash->{extra_rules_desc} = $c->stash->{ruleset}->rules_description;
   $c->stash->{c_letter} = \&column_letter;
   $c->stash->{template} = 'game.tt';
}

#returns error string if error
sub seek_permission_to_move{
   my $c = shift;
   return 'not logged in' unless $c->session->{logged_in};
   return 'not registered' if $c->session->{userid} == 1;
   my $game = $c->stash->{game};
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
   my $game = $c->stash->{game};
   my $nummoves = $game->num_moves;
   return 'You hound! You just started!' unless $nummoves >= 2;
   return 'lastmove not pass' unless $game->moves->find ({movenum => $nummoves})->movestring eq 'pass';
   return '2nd-to-lastmove not pass' unless $game->moves->find ({movenum => $nummoves-1})->movestring eq 'pass';
   return '';
}


sub build_rulemap{
   my $c = shift;
   my $game = $c->stash->{game};
   my $rulemap = new basilisk::Rulemap(
      size => $game->size,
      topology => 'plane',
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

#todo: Return as soon as it passes. Generate the new board in do_move
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
sub do_move{#todo:mv to game class?
   my ($c, $movestring, $newboard, $caps) = @_;
   my $new_pos_data;
   my $side = $c->stash->{side}; #1 if B,2 if W
   my $size = $c->stash->{game}->size;
   
   #determine move string and new position
   if ($movestring eq 'pass'){
      $new_pos_data = $c->stash->{old_pos_data};
   }
   else { # stone placement
      my ($row, $col) = ($c->stash->{move_row}, $c->stash->{move_col});
      $movestring = ($side==1?'b':'w') . " row$row, col$col";
      $new_pos_data = Util::pack_board($newboard, $size);
   }
   Util::ensure_position_size($new_pos_data, $size);
   
   #transaction!
   $c->model('DB')->schema->txn_do(  sub{
      if ($caps and @$caps){ #update capture count
         my $p2g = $c->stash->{p2g};#player_to_game
         $p2g->set_column('captures',$p2g->captures + @$caps); #INT
         $p2g->update;
      }
      my $posrow = $c->model('DB::Position')->create( {
         ruleset => $c->stash->{ruleset}->id,
         position => $new_pos_data,
      });
      my $moverow = $c->model('DB::Move')->create( {
         gid => $c->stash->{game}->id,
         position_id => $posrow->id,
         movestring => $movestring,
         movenum => $c->stash->{game}->num_moves+1,
         time => time,
      });
      $c->stash->{game}->shift_turn; #b to w, etc num_moves++
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
   return \@playerdata;
   
}

#todo: move url param stuff into tt
sub render_board_table{
   my ($c) = @_;
   my $size = $c->stash->{game}->size;
   my $board = $c->stash->{board};
   my $death_mask = $c->stash->{death_mask};
   my $terr_mask = $c->stash->{territory_mask} or {};
   my @table; #html cells representing nodes
   
   for my $row (0..$size-1){
      for my $col (0..$size-1){ #get image and url for table cell
         my $image = select_g_file ($board, $size, $row, $col);
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
   my ($board, $size, $row, $col) = @_;
   my $stone = $board->[$row][$col];
   return 'b.gif' if $stone == 1;
   return 'w.gif' if $stone == 2;
   #so it's an empty intersection
   #several empties to choose from:
   if ($row == 0){
      return 'ul.gif' if $col == 0;
      return 'ur.gif' if $col == $size-1;
      return 'u.gif' ;
   }
   if ($row == $size-1){
      return 'dl.gif' if $col == 0;
      return 'dr.gif' if $col == $size-1;
      return 'd.gif' ;
   }
   return 'el.gif' if $col == 0;
   return 'er.gif' if $col == $size-1;
   return 'e.gif'
}

my @cletters = qw/a b c d e f g h j k l m n o p q r s t u v w x y z/;

sub column_letter{
   my $c = shift;
   return $cletters[$c]
}

1;
