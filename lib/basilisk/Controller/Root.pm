package basilisk::Controller::Root;

use strict;
use warnings;
use parent 'Catalyst::Controller';


# this is so the path doesn't need prefix /root/
# but I'm only using global actions anyways..
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


#list of all registered players
sub players :Global{
   my ( $self, $c ) = @_;
   
   $c->stash->{message} = 'Hello. Here\'s some wood:<br>' . 
      '<img src="/g/wood.gif" />';
   $c->stash->{template} = 'message.tt';
}
#list of all games on server
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

1;
