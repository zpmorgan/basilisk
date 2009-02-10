package basilisk::Controller::Root;

use strict;
use warnings;
use parent 'Catalyst::Controller';

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#wait what?
__PACKAGE__->config->{namespace} = '';


sub index :Path :Args(0) {
   my ( $self, $c ) = @_;
   
   # Hello World
   if ($c->session->{'username'}){
      $c->stash->{'template'} = 'welcome.tt'
   }
   else{
     $c->stash->{'template'} = 'login.tt';
   }
}

sub game : Local {
   my ( $self, $c ) = @_;
   
   # Hello World 
   $c->stash->{'title'}= "Game 34343, move 12";
   $c->session->{'num'}++;
   $c->stash->{'num'} = $c->session->{'num'};
   $c->stash->{'board'} = \&board_html;
   #my $page = $c->forward('basilisk::View::TT', {gamenum => 4});
   #$c->response->body( $page );
   #die $page;
}


sub players :Global{
   my ( $self, $c ) = @_;
   
   $c->stash->{message} = 'hey.';
   $c->stash->{template} = 'message.tt';
}
sub games :Global{
   my ( $self, $c ) = @_;
   
   $c->stash->{message} = 'Sorry, you are about to lose the game';
   $c->stash->{template} = 'message.tt';
}


sub status :Global{
   my ( $self, $c ) = @_;
   $c->stash->{'template'} = 'status.tt';
   
}

sub default :Path {
   my ( $self, $c ) = @_;
   my $req = $c->request;
   my @info; # = ("Page'sn't found!");
   push @info, "referer: ".$req->referer;
   push @info, "secure: ".$req->secure;
   push @info, "args: " . join ', ', @{$req->args};
   push @info, "params: ",%{$req->parameters};
   push @info, "session data: ";
   for my $key (keys %{$c->session}){
      push @info, " * $key: ". $c->session->{$key};
   }
   $c->stash->{body} = join "<br>",@info;
   $c->stash->{template} = '404.tt';
#   $c->response->body( join "<br>",@info);
   $c->response->status(404);
}



# end -- Attempt to render a view.

sub end : ActionClass('RenderView') {
    #this is a RenderView action, so it's called afterwards
   my ( $self, $c ) = @_;
   #set some tt var for header
   $c->stash->{logged_in} = $c->session->{logged_in} ? 1 : 0;
   $c->stash->{name} = $c->session->{logged_in} ? $c->session->{name} : 'you';
}

sub board_html{
   return "<br>And here'sn't a board!<br>";
}

1;
