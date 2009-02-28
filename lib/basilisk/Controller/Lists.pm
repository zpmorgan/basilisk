package basilisk::Controller::Lists;

use strict;
use warnings;
use parent 'Catalyst::Controller';
__PACKAGE__->config->{namespace} = '';

#list of all registered players
sub players :Global{
   my ( $self, $c ) = @_;
   
   $c->stash->{message} = 'Hello. Here\'s some wood:<br>' . 
      '<img src="[% img_base %]/wood.gif" />';
   $c->stash->{template} = 'message.tt';
}


#list of all games on server
sub games :Global{
   my ( $self, $c ) = @_;
   
   $c->stash->{title} = 'All games';
   $c->stash->{template} = 'all_games.tt';
   my $rs = $c->model('DB::Game')->search({}, {rows=>25})->page(0);
   #todo: p2g joined with game & player tables with prefetch (outer join)
   my @games_data; #this is what template uses
   for my $game($rs->all) {
      push @games_data, {
         id => $game->id,
         bname => 'blackie',
         wname => 'whitie',
         size => $game->size,
      }
   }
   $c->stash->{games_data} = \@games_data
}



sub add_wgame{
   my $c = shift;
   return 'log in first' unless $c->session->{logged_in};
   my $topo = $c->req->param('topology');
   my ($ew, $ns) = (0,0); #sides which wrap around
   $ew = 1 if $topo eq 'cylinder' or $topo eq 'torus';
   $ns = 1 if $topo eq 'torus';
   my $desc = ''; # description of interesting rules
   $desc .= $topo unless $topo eq 'plane';  #planes are not interesting
   
   $c->model('DB')->schema->txn_do(  sub{
      my $new_ruleset = $c->model('DB::Ruleset')->create ({ 
         size => $c->req->param('size'),
         #wrap_ew => $ew,
         #wrap_ns => $ns,
         rules_description => $desc,
      });
      my $row = $c->model('DB::Game_proposal')->create({
         quantity => $c->req->param('quantity'),
         proposer => $c->session->{userid},
         ruleset => $new_ruleset->id,
      });
   });
   return ''; #no err
}


#join a game, from waiting room
#this just wraps create_2player_game in a transaction
sub create_game{
   my ($c, $ruleset_id, $players, $wgame) = @_;
   my ($b,$w) = @$players;
   my $game;
   
   $c->model('DB')->schema->txn_do( sub{
      $game = $c->model('DB::Game')->create({
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
      $wgame->decrease_quantity;
   } );
   $c->stash->{newgame} = $game;
}

sub join_wgame{
   my $c = shift;
   return 'log in first' unless $c->session->{logged_in};
   my $wgame_id = $c->req->param('wgameid');
   my $wgame = $c->model('DB::Game_proposal')->find({id => $wgame_id});
   return "wgame $wgame_id doesn't exist." unless $wgame;
   my $ruleset_id = $wgame->ruleset;
   
   create_game ($c,  $ruleset_id, [$wgame->proposer->id, $c->session->{userid}], $wgame) ;
   return ''; #no err
}



sub waiting_room :Global{
   my ( $self, $c ) = @_;
   if ($c->req->param('action')){
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
         my $id = $c->stash->{newgame}->id;
         $c->stash->{msg} = "<a href='[%url_base%]/game/$id'>Game joined!</a>";
         #TODO: forward to joined game?
      }
   }
   $c->stash->{title} = 'Waiting room';
   $c->stash->{template} = 'waiting_room.tt';
   my @waiting_rs = $c->model('DB::Game_proposal')->search( #todo:join with ruleset
      {},
      {join => ['proposer', 'ruleset'],
        '+select' => ['proposer.name', 'proposer.id', 'ruleset.rules_description'], 
        '+as'     => ['name', 'proposer_id', 'description'],
      },
   );
   
   my @waiting_games_info; #for TT
   for my $waiting(@waiting_rs) {
      push @waiting_games_info,{ #todo:topology? maybe generate some description string?
         id => $waiting->id,
         proposer => $waiting->get_column('name'),
         proposer_id => $waiting->get_column('proposer_id'),
         size => $waiting->size,
         desc => $waiting->get_column('description'),
      }
   }
   $c->stash->{waiting_games_info} = \@waiting_games_info;
   
   #if user requests info on a specific wgame:
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
   # names of only numbers are  forbidden
   my ($user) = $c->req->path =~ m|userinfo/(\w*)|;
   unless ($user){
      $user = $c->session->{logged_in} ? $c->session->{name} : 'guest';
   }
   
   my $row;
   my ($id, $name);
   if ($user =~ /^\d*$/){ #only digits from url path
      $row = $c->model('DB::Player')->find({id => $user});
      $id = $user;
      $name = $row->name;
   }
   else{
      $row = $c->model('DB::Player')->find({name => $user});
      $id = $row->id;
      $name = $user;
   }
   
   my %userinfo = (
      id => $id,
      name => $name,
   );
   
   $c->stash->{userinfo} = \%userinfo;
   $c->stash->{template} = 'userinfo.tt';
}

1;

