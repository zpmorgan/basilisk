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
   $c->stash->{last_move} = $c->stash->{game}->last_move;
   $c->stash->{template} = 'game.tt';
   $c->stash->{title}= "Game ".$c->stash->{gameid}.", move ".$c->stash->{last};
   $c->session->{num}++;
   $c->stash->{num} = $c->session->{'num'};
   $c->stash->{board} = render_board_html($c,$gameid);
   
   #$c->stash->{render_board} = sub{render_board_html($c,$gameid)};
   #my $page = $c->forward('basilisk::View::TT', {gamenum => 4});
   #$c->response->body( $page );
   #die $page;
}


sub render_board_html{
   my ($c,$gameid) = @_;
   my $size = $c->stash->{game}->size;
   my @lines;
   push @lines, "<br>And here's a pseudoboard!<br>";
   push @lines, "board size: $size<br>";
   my $pos = $c->stash->{game}->current_position;
   my $board = Util::unpack_position($pos, $size);
   
   #render board position as a table
   push @lines, q|<table  class="Goban" style="background-image: url(/g/wood.gif);">|;
   for my $row (@$board){
      push @lines, q|<tr>|;
      for my $i (@$row){
         push @lines, q|<td class="brdx"> <img class="brdx" src="/g/e.gif" /> </td>|;
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
