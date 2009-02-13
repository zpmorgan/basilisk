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
   if ($c->session->{name}){
      $c->stash->{message} = 'Hello, ' . $c->session->{name};
      $c->stash->{template} = 'message.tt';
   }
   else{
      $c->stash->{title} = 'log in';
      $c->stash->{name} = $c->session->{name};
      $c->stash->{template} = 'login.tt';
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
   
   $c->stash->{title} = 'All games';
   $c->stash->{template} = 'all_games.tt';
   my @lines = ('<table>');
   my $rs = $c->model('DB::Game')->search({}, {rows=>25})->page(0);
   for my $game($rs->all) {
      my $id = $game->id;
      push @lines, qq|<tr><td><a href="/game/$id">$id</a></td></tr>|;
   }
   push @lines , '</table>';
   $c->stash->{games_table} = join "\n", @lines;
}


sub status :Global{
   my ( $self, $c ) = @_;
   $c->stash->{title} = $c->session->{name} . '\'s status';
   #$c->stash->{username} = $c->session->{name};
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
#this is a RenderView action, so this is called right before we're sent to the view
sub end : ActionClass('RenderView') {
   my ( $self, $c ) = @_;
   #set some tt var for header
   $c->stash->{logged_in} = $c->session->{logged_in} ? 1 : 0;
   $c->stash->{username} = $c->session->{logged_in} ? $c->session->{name} : 'you';
   $c->session->{num}++;
   $c->stash->{num} = $c->session->{num};
}

1;
