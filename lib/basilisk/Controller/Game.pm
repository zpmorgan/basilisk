package basilisk::Controller::Game;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use basilisk::Util;


__PACKAGE__->config->{namespace} = '';

# /game/14?action=move&co=4-4
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
   my $pos_data = $c->stash->{game}->current_position;
   
   my $size = $c->stash->{game}->size;
   my $board = Util::unpack_position($pos_data, $size);
   @{$c->stash}{qw/pos_data board/} = ($pos_data, $board); #put board data in stash
   
   my $action = $c->req->param('action');
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
         $c->model('DB')->schema->txn_do(
           \&do_move, $c, $newboard, $caps
         );
         $c->stash->{board} = $newboard;
         $c->stash->{msg} = 'move is success';
      }
   }
   $c->stash->{last_move} = $c->stash->{game}->last_move;
   $c->stash->{title} = "Game ".$c->stash->{gameid}.", move ".$c->stash->{last_move};
   $c->stash->{players_data} = get_game_player_data($c);
   render_board_table($c);
   $c->stash->{to_move_img} = ($c->stash->{game}->turn) == 1 ? 'b.gif' : 'w.gif';
   $c->stash->{extra_rules_desc} = $c->stash->{ruleset}->rules_description;
   $c->stash->{c_letter} = \&column_letter;
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

#todo: move all mv eval into some ruleset module

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
   my $size = $c->stash->{game}->size;
   my $turn = $c->stash->{game}->turn;
   if ($board->[$row][$col]){
      return "stone exists at row $row col $col";
   }
   
   #produce copy of board for evaluation -> add stone at $row $col
   my $newboard = [ map {[@$_]} @$board ];
   $newboard->[$row]->[$col] = $turn;
   # $string is a list of strongly connected stones: $foes=enemies adjacent to $string
   my ($string, $libs, $foes) = Util::get_string($newboard, $row, $col);
   my $caps = Util::find_captured ($newboard, $foes);
   if (@$libs == 0 and @$caps == 0){
      return 'suicide';
   }
   for my $cap(@$caps){ # just erase captured stones
      $newboard->[$cap->[0]]->[$cap->[1]] = 0;
   }
   if (detect_duplicate_position($c, $newboard)){
      return 'Ko error: this is a repeating position from move '.$c->stash->{oldmove}->movenum
   }
   return ('',$newboard, $caps);#no err
}
#die join';',map{@$_}@$libs; #err list of coordinates


sub do_move{#todo:mv to game class?
   my ($c, $newboard, $caps) = @_;
   my ($row, $col) = ($c->stash->{move_row}, $c->stash->{move_col});
   my $side = $c->stash->{side}; #1 if B,2 if W
   #die $side;
   my $size = $c->stash->{game}->size;
   my $new_pos_data = Util::pack_board($newboard, $size);
   
   $c->stash->{new_pos_data} = $new_pos_data;
   my $posrow = $c->model('DB::Position')->create( {
      size => $size,
      position => $new_pos_data,
   });
   my $moverow = $c->model('DB::Move')->create( {
      gid => $c->stash->{game}->id,
      position_id => $posrow->id,
      move => ($side==1?'b':'w') . " $row, $col",
      movenum => $c->stash->{game}->next_move,
      time => time,
   });
   $c->stash->{game}->shift_turn; #b to w, etc
   if (@$caps){ #update capture count
      my $p2g = $c->stash->{p2g};#player_to_game
      $p2g->set_column('captures',$p2g->captures + @$caps); #INT
      $p2g->update;
   }
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


sub render_board_table{
   my ($c) = @_;
   my $size = $c->stash->{game}->size;
   my $board = $c->stash->{board};
   my @table; #cells representing one intersection each
   #todo: coordinate letters 
   for my $rownum (0..$size-1){
      #todo: coordinate number column
      for my $colnum (0..$size-1){ #form one intersection. 
         my $stone = $board->[$rownum]->[$colnum]; #0 if empty, 1 b, 2 w
         my $image = select_g_file ($stone, $size, $rownum, $colnum);
         $table[$rownum][$colnum]->{g} = $image;
         if ($stone==0){ #empty
            my $url = "/game/".$c->stash->{gameid} . "?action=move&co=" . $rownum .'-'.$colnum;
            $table[$rownum][$colnum]->{ref} = $url;
         }
      }
   }
   $c->stash->{board_data} = \@table;
}

sub select_g_file{ #default board
   my ($stone, $size, $row, $col) = @_;
   return 'b.gif' if $stone == 1;
   return 'w.gif' if $stone == 2;
   #$stone==0 -- so it's an empty intersection
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

sub get_game_board{
   my ($c) = @_;
   my $game = $c->stash->{game};
   my $pos = $game->current_position;
   return Util::unpack_position($pos, $game->size);
}

sub game_exists{
   my ($c) = @_;
   return 1 if $c->model('DB::Game')->count( 'id' => $c->stash->{gameid});
   return 0;
}

my @cletters = qw/a b c d e f g h j k l m n o p q r s t u v w x y z/;

sub column_letter{
   my $c = shift;
   return $cletters[$c]
}

1;
