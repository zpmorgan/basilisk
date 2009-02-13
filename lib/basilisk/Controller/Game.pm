package basilisk::Controller::Game;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use basilisk::Util;


# /game/14?foo=bar
sub game : Global {
   my ( $self, $c ) = @_;
   #extract game id from path
   my ($gameid) = $c->req->path =~ m|game/(\d*)|;
   $c->stash->{gameid} = $gameid;
   $c->stash->{game} = $c->model('DB::Game')->search( 'id' => $c->stash->{gameid})->next;
   unless ($gameid ){
      $c->stash->{message} = 'invalid request: please supply a game id';
      $c->stash->{template} = 'message.tt';return;
   }
   unless ($c->stash->{game}){
      $c->stash->{message} = 'invalid request: no game with that id';
      $c->stash->{template} = 'message.tt';return;
   }
   $c->stash->{players_html} = display_players_html($c);
   $c->stash->{last_move} = $c->stash->{game}->last_move;
   $c->stash->{template} = 'game.tt';
   $c->stash->{title}= "Game ".$c->stash->{gameid}.", move ".$c->stash->{last};
   $c->session->{num}++;
   $c->stash->{num} = $c->session->{'num'};
   $c->stash->{board_html} = render_board_html($c,$gameid);
   
   #$c->stash->{render_board} = sub{render_board_html($c,$gameid)};
   #my $page = $c->forward('basilisk::View::TT', {gamenum => 4});
   #$c->response->body( $page );
   #die $page;
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

sub display_players_html{
   my ($c) = @_;
   my @lines;
   #get player-game data
   my @players = $c->model('DB::Player_to_game')->search( 
      {gid => $c->stash->{gameid}},
      {join => 'player',
         '+select' => ['player.name', 'player.id'],
         '+as'     => ['name', 'id']
      }
   );
   
   
   push @lines, q|<table>|;
   for my $p (@players){
      push @lines, q|<tr>|;
      #stone graphic
      push @lines, q| <td> <img src="/g/| . ($p->side==0 ? 'b' : 'w') . q|.gif"> </td>|;
      #player name
      push @lines, q| <td> <b>| . $p->get_column('name') . q|</b> </td>|;
      #player time remaining
      push @lines, q| <td> <b>| . $p->time_remaining . q|</b> </td>|;
      
      push @lines, q|</tr>|;
   }
   push @lines, q|</table>|;
   return join "\n", @lines;
}

sub render_board_html{
   my ($c) = @_;
   my $size = $c->stash->{game}->size;
   my @lines;
   push @lines, "<br>And here's a pseudoboard!<br>";
   push @lines, "board size: $size<br>";
   my $pos = $c->stash->{game}->current_position;
   my $board = Util::unpack_position($pos, $size);
   
   #render board position as a table
   push @lines, q|<table  class="Goban" style="background-image: url(/g/wood.gif);">|;
   for my $rownum (0..$size-1){
      push @lines, q|<tr>|;
      for my $colnum (0..$size-1){
         push @lines, q|<td class="brdx"> <img class="brdx" src="/g/| . 
            select_g_file ($board->[$rownum]->[$colnum], $size, $rownum, $colnum)
            . q|" /> </td>|;
      }
      push @lines, q|</tr>|;
   }
   #push @lines, join "<br>\n",map{join" ",@$_} @$board;
   push @lines, '</table>';
   return join "\n", @lines;
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

1;
