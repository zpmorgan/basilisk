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

sub add_wgame{
   my $c = shift;
   return 'log in first' unless $c->session->{logged_in};
   
   my $row = $c->model('DB::Game_proposal')->create({
      quantity => $c->req->param('quantity'),
      proposer => $c->session->{userid},
      #size => $c->req->param('size'),
      ruleset => 1,
   });
   return ''; #no err
}

#join a game, from waiting room

sub create_game{
   my ($c, $b, $w, $ruleset_id) = @_;
   
   #die $w;
   $c->model('DB')->schema->txn_do(\&create_2player_game, $c, $b, $w, $ruleset_id)
}

sub create_2player_game{ # called as one transaction
   my ($c, $b, $w, $ruleset_id) = @_;
   my $game = $c->model('DB::Game')->create({
      ruleset => $ruleset_id,
   });
   $c->model('DB::Player_to_game')->create({
      gid => $game->id,
      pid => $b,
      side => 1, #black
      expiration => 0,
   });
   $c->model('DB::Player_to_game')->create({
      gid => $game->id,
      pid => $w,
      side => 2, #white
      expiration => 0,
   });
}


sub join_wgame{
   my $c = shift;
   return 'log in first' unless $c->session->{logged_in};
   my $wgame_id = $c->req->param('wgameid');
   my $wgame = $c->model('DB::Game_proposal')->find({id => $wgame_id});
   return "wgame $wgame_id doesn't exist." unless $wgame;
   my $ruleset_id = $wgame->ruleset;
   
   create_game ($c, $wgame->proposer->id, $c->session->{userid}, $ruleset_id) ;
   $wgame->decrease_quantity;
   return ''; #no err
}

sub waiting_room :Global{ #TODO: @lines is wrong, use TT
   my ( $self, $c ) = @_;
   $c->stash->{msg} = $c->session->{userid};
   if ($c->req->param('action') eq 'add_wgame'){
      my $err = add_wgame($c);
      if ($err){
         $c->stash->{message} = "error: $err";
         $c->stash->{template} = 'message.tt'; return
      }
      $c->stash->{msg} = 'Game added';
   }
   elsif ($c->req->param('action') eq 'join'){
      my $err = join_wgame($c);
      if ($err){
         $c->stash->{message} = "error: $err";
         $c->stash->{template} = 'message.tt'; return
      }
      $c->stash->{msg} = 'Game joined!';
      #TODO: forward to joined game
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
      my $name = $row->get_column('name');
      push @lines, qq|<tr>|;
       push @lines, qq|<td><a href="/waiting_room/$id">$id</a></td>|;
       push @lines, q|<td> <a href="/userinfo/| . $row->get_column('proposer_id') . q|">| . $row->get_column('name') . q|</a></td>|;
       push @lines, qq|<td>$size</td>|;
      push @lines, qq|</tr>|;
   }
   push @lines , '</table>';
   $c->stash->{waiting_games_table} = join "\n", @lines;
   
   my ($wgame_id) = $c->req->path() =~ m|/(\d*)|;#extract wgame id from path
   if ($wgame_id){ #display a ruleset and a join button
      my $wgame = $c->model('DB::Game_proposal')->find({id => $wgame_id});
      unless ($wgame){ #err
         $c->stash->{message} = "Sorry no waiting game with id $wgame_id";
         $c->stash->{message} = 'message.tt';  return;
      }
      $c->stash->{proposal_info}->{id} = $wgame_id;
      $c->stash->{proposal_info}->{quantity} = $wgame->quantity;
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
   #$user could be a player's id or name
   #TODO: forbid names of only numbers, or change this
   my ($user) = $c->req->path =~ m|userinfo/(\w*)|;
   unless ($user){
      $user = $c->session->{logged_in} ? $c->session->{name} : 'guest';
   }
   my $row;
   if ($user =~ /^\d*$/){ #only digits from url path
      $row = $c->model('DB::Player')->find({id => $user});
   }
   else{
      $row = $c->model('DB::Player')->find({name => $user});
   }
   
   my $id = $row->id;
   
   $c->stash->{title} = $row->name . '\'s info';
   my @lines;
   push @lines, $row->name . '\'s info:';
   push @lines, '<table>';
   #link to player's games table
   push @lines, '<tr> <td>Games</td> <td><a href="/games?playerid='.$id.'">games</a></td> </tr>';
   push @lines, '<tr> <td>Rank</td> <td>' .int rand()*30+1 . 'k</td> </tr>';
   
   
   push @lines, '</table>';
   $c->stash->{message} = join "\n", @lines;
   $c->stash->{template} = 'message.tt';
}

1;

