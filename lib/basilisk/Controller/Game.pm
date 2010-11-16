package basilisk::Controller::Game;

use strict;
use warnings;
use parent 'Catalyst::Controller';

#use basilisk::Rulemap;

__PACKAGE__->config->{namespace} = 'game';

sub selfgame : Global{
   my ( $self, $c ) = @_;
   $c->stash->{gameid} = 1;
   $c->stash->{template} = 'game.tt';
}
sub game : Global{
   my ( $self, $c, $gameid ) = @_;
   $c->stash->{gameid} = $gameid;
   my $game = $c->model('DB::Game')->find($gameid);
   $c->stash->{template} = 'game.tt';
}
