package basilisk::Controller::Lists;

use strict;
use warnings;
use parent 'Catalyst::Controller';
__PACKAGE__->config->{namespace} = '';

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
sub waiting_room :Global{
   my ( $self, $c ) = @_;
   
   if ($c->req->param('action')){
      my $err = add_waiting_game($c);
      $c->stash->{message} = $err ? $err : 'Game added';
      $c->stash->{template} = 'message.tt'; return
   }
   
   $c->stash->{title} = 'Waiting room';
   $c->stash->{template} = 'waiting_room.tt';
   my @lines = ('<table border="1">');
   push @lines, q|<tr><td>id</td><td>proposer</td><td>size</td></tr>|;
   my @rows = $c->model('DB::Game_proposal')->search(
      {},
      {join => 'proposer',
        '+select' => ['proposer.name', 'proposer.id'], 
        '+as'     => ['name', 'proposer_id'],
      },
   );
   for my $row(@rows) {
      my $id = $row->id;
      my $size = $row->size;
      my $from = $row->from;
      push @lines, qq|<tr>|;
       push @lines, qq|<td><a href="/waiting_room/$id">$id</a></td>|;
       push @lines, q|<td> <a href="/userinfo/| . $row->get_column('proposer_id') . q|">| . $row->get_column('name') . q|</a></td>|;
       push @lines, qq|<td>$size</td>|;
      push @lines, qq|</tr>|;
   }
   push @lines , '</table>';
   $c->stash->{waiting_games_table} = join "\n", @lines;
   my ($wgame_id) = $c->req->path() =~ m|/\d*|;#extract wgame id from path
   if ($wgame_id){ #display a ruleset and a join button
      my $wgame = $c->model('DB::Game_proposal')->find({id => $wgame_id});
      unless ($wgame){ #err
         $c->stash->{message} = "Sorry no waiting game with id $wgame_id";
         $c->stash->{message} = 'message.tt';  return;
      }
      #reuse @lines
      #@lines = ();
      #push @lines, ""
      $c->stash->{proposal_info}->{size} = $wgame->size;
      $c->stash->{proposal_info}->{proposer} = $wgame->proposer;
   }
   else{
      #use a proposal form template
      #$c->stash->{proposal_info} = $proposal_form;
   }
}

sub status :Global{
   my ( $self, $c ) = @_;
   $c->stash->{title} = $c->session->{name} . '\'s status';
   #$c->stash->{username} = $c->session->{name};
   $c->stash->{'template'} = 'status.tt';
}

sub userinfo :Global{
   my ( $self, $c ) = @_;
   #my ($userid) = $c->req->path =~ m|user/(\d*)|;
   my ($name) = $c->req->path =~ m|user/(\w*)|;
   unless ($name){
      $name = $c->session->{logged_in} ? $c->session->{name} : 'guest';
   }
   my $row = $c->model('DB::Player')->find({name => $name});
   my $id = $row->id;
   
   $c->stash->{title} = $name . '\'s info';
   my @lines;
   push @lines, $row->name . '\'s info:';
   push @lines, '<table>';
   #link to player's games table
   push @lines, '<tr> <td>Games</td> <td><a href="/games?playerid='.$id.'">games</a></td> </tr>';
   push @lines, '<tr> <td>Rank</td> <td>' .int rand()*30+1 .'k</td> </tr>';
   
   
   push @lines, '</table>';
   $c->stash->{message} = join "\n", @lines;
   $c->stash->{template} = 'message.tt';
}

1;

