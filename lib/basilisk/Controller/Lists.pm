package basilisk::Controller::Lists;

use strict;
use warnings;
use parent 'Catalyst::Controller';
__PACKAGE__->config->{namespace} = '';

#inbox, etc
sub messages :Global{
   my ( $self, $c ) = @_;
   
   $c->stash->{message} = 'Hello. Here\'s some wood:<br>' . 
      '<img src="[% img_base %]/wood.gif" />';
   $c->stash->{template} = 'message.tt';
}

#list of all registered players
sub players :Global{
   my ( $self, $c ) = @_;
   my $page = 0;
   my $players_rs;
   $c->model('DB')->schema->txn_do( sub{
      $players_rs = $c->model('DB::Player')->search({}, {rows=>25})->page($page);
   });
   my @players_info;
   for my $p ($players_rs->all){
      push @players_info, {
          name => $p->name,
          id => $p->id,
       };
   }
   $c->stash->{playerinfo} = \@players_info;
   $c->stash->{template} = 'players.tt';
}

#todo: prefetch?
sub get_list_of_games{
   my ($c, $page, $playername) = @_;
   my $pagesize = 25;
   my ($num_games, $num_pages);
   my %gameplayers; #to show who plays which game
   my %rulestrings; #to summarize game rulesets
   my $games_rs;
   my $gamesearch_constraints = {status => Util::RUNNING()};
   #transaction!
   $c->model('DB')->schema->txn_do( sub{
      my $gid_col; #used to resolve resultset col naming issue
      if ($playername){#only look at this player's games
         my $p = $c->model('DB::Player')->find ({name=>$playername});
         return 'nosuchplayer' unless $p;
         my $relevant_p2g = $c->model('DB::Player_to_game')->search(
            {'me.pid' => $p->id},
            #{select => ['me.pid'], as => ['blah']}
         );
         $games_rs = $relevant_p2g->search_related('game',
              $gamesearch_constraints, 
              {rows => $pagesize,
               }#select => ['game.id'], as => ['gid'] }
         )->page($page);
         $gid_col = 'game.id'; 
      }
      else{
         $games_rs = $c->model('DB::Game')->search(
              $gamesearch_constraints, 
              {rows=>$pagesize,
               }#'+select' => ['id'], '+as' => ['id']}
         )->page($page);
         $gid_col = 'me.id';
      }
      my $p2g_rs = $games_rs->search_related ('player_to_game', {}, #all related
         {
            join => ['player'],
            select => ['player.name', $gid_col, 'player_to_game.pid', 'player_to_game.side'],
            as => ['pname', 'gid', 'pid', 'side'],
         });
      $num_games = $games_rs->count();
      for my $p2g ($p2g_rs->all()){ #who plays what game
         my %data = $p2g->get_columns;
         $gameplayers{$data{gid}}->[$data{side}] = \%data; #note: 'side' is 1 or 2
      }
      #now get ruleset summary
      my $rulesets_rs = $games_rs->search ( {}, 
         {
            join => 'ruleset',
            select => [$gid_col, 'ruleset.rules_description'],
            as => ['gid', 'rulestring'],
         });
      for my $row($rulesets_rs->all()){
         $rulestrings{$row->get_column('gid')} = $row->get_column('rulestring');
      }
   });#end transaction
   
   $c->stash->{num_pages} = int ($num_games / $pagesize) + 1;
   $c->stash->{num_games} = $num_games;
   
   my @games_data; #this is what template uses
   my %seen; #unique games in @games_data
   for my $game($games_rs->all) {
      next if $seen{$game->id};
      $seen{$game->id} = 1;
      
      my $gid = $game->id;
      push @games_data, { #todo: make generic for 3+ players
         id => $gid,
         bname => $gameplayers{$gid}->[1]->{pname},
         wname => $gameplayers{$gid}->[2]->{pname},
         bid => $gameplayers{$gid}->[1]->{pid},
         wid => $gameplayers{$gid}->[2]->{pid},
         rulestring => $rulestrings{$gid}, #$game->size,
      }
   }
   return \@games_data;
}

#list of all games on server
sub games :Global{
   my ( $self, $c, $player) = @_;
   $c->stash->{title} = 'All games';
   $c->stash->{title} .= " of $player" if $player;
   $c->stash->{template} = 'all_games.tt';
   my $games_data = get_list_of_games ($c,0, $player); 
   $c->stash->{games_data} = $games_data #this is for template
}



sub add_wgame{
   my $c = shift;
   return 'log in first' unless $c->session->{logged_in};
   my $topo = $c->req->param('topology');
   my $h = $c->req->param('h');
   my $w = $c->req->param('w');
   my $desc = $w .'x'. $h; # description of interesting rules
   $desc .= $topo unless $topo eq 'plane';  #planes are not interesting
   
   $c->model('DB')->schema->txn_do(  sub{
      my $new_ruleset = $c->model('DB::Ruleset')->create ({ 
         h => $c->req->param('h'),
         w => $c->req->param('w'),
         rules_description => $desc,
      });
      my $row = $c->model('DB::Game_proposal')->create({
         quantity => $c->req->param('quantity'),
         proposer => $c->session->{userid},
         ruleset => $new_ruleset->id,
      });
      unless ($topo eq 'plane'){
         $c->model('DB::Extra_rule')->create({
            rule => $topo,
            priority => 2,
            ruleset  => $new_ruleset->id,
         });
      }
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

