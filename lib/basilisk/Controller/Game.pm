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
   #die $c->stash->{game};
   unless ($gameid ){
      $c->stash->{message} = 'invalid request: please supply a game id';
      $c->stash->{template} = 'message.tt';return;
   }
   unless (game_exists($c,$gameid) ){
      $c->stash->{message} = 'invalid request: no game with that id';
      $c->stash->{template} = 'message.tt';return;
   }
   $c->stash->{current_move} = current_move($c);
   $c->stash->{template} = 'game.tt';
   $c->stash->{title}= "Game ".$c->stash->{gameid}.", move ".$c->stash->{current_move};
   $c->session->{num}++;
   $c->stash->{num} = $c->session->{'num'};
   $c->stash->{render_board} = sub{render_board_html($c,$gameid)};
   #my $page = $c->forward('basilisk::View::TT', {gamenum => 4});
   #$c->response->body( $page );
   #die $page;
}


sub render_board_html{
   my ($c,$gameid) = @_;
   my $size = $c->stash->{game}->size;
   my @lines;
   push @lines, "<br>And here'sn't a board!<br>";
   push @lines, "Here's size of game 1: ";
   
   my $size = $c->stash->{game}->size;
   push @lines, $size."<br>";
   my $pos = $c->stash->{game}->current_position;
   my $board = Util::unpack_position($pos, $size);
   push @lines, join "<br>\n",map{join" ",@$_} @$board;
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

sub current_move{
   my ($c) = @_;
   my $mv_count = $c->model('DB::Move')->count( 'gid' => $c->stash->{gameid});
   return $mv_count + 1;
}

1;
