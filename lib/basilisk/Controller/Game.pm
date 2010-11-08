package basilisk::Controller::Game;

use strict;
use warnings;
use parent 'Catalyst::Controller';

use basilisk::Rulemap;

__PACKAGE__->config->{namespace} = 'game';

sub selfgame : Global{
   my ( $self, $c ) = @_;
   $c->stash->{template} = 'game.tt';
   
}
