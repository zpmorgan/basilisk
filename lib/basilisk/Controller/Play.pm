package basilisk::Controller::Play;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use basilisk::Rulemap;
use JSON;
#__PACKAGE__->config->{namespace} = '';

#this page is for active games & players to be displayed, as well as a
#chat interface for online users.

sub play : Global {
   my ( $self, $c ) = @_;
   $c->stash->{template} = 'play.tt';
   
}




1;
