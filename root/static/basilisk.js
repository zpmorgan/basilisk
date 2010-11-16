
var active_game;
var R;

function Ruleset(w, h, topo, komi, handi){
   this.rows = h;
   this.cols = w;
   this.topology = 'topo';
   this.komi = komi;
   this.handi = handi;
}

function Game (gameid, rules, players)
{
   this.id = gameid;
   this.rules = rules;
   this.players = players;
   this.events = [];
}

Game.prototype.post_events = function(after, events){
   while (after > this.events.length){
      events.shift();
      after++;
   }
   while (events.length){
      this.post_event(events.shift());
   }
   
}

Game.prototype.post_event = function (event){
   if (event.type == "comment"){
      
   }
   else if (event.type == "move"){ // do a delta
      //todo: also update current board state in $this.
      R.renderDelta(event.delta);
   }
}

Game.prototype.attemptMove = function(node){
   $.ajax({
      url: url_base + "/rt/game",
      data: {
         action: 'move',
         move: node,
         after: this.events.length,
         gameid: this.id,
      },
      dataType: "json",
      type: "POST",
      success: function(data) {
         this.post_events (data.after, data.events);
      }
   });
}


function Renderer (game){ //Canvas renderer.
   this._game = game;
   this._canvas = 0;
   this._bgColor = "goldenrod";
   this._lineColor = "black";
   this._scrolledX = 0;
   this._scrolledY = 0;
   this._padding = 20; // for labels
   this._halfLine = 15;
   this._wrapX = 0;
   this._wrapY = 0;
}

Renderer.prototype.renderBoard = function(){
   //fill with bgcolor.
   var ctx = this._ctx;
   ctx.fillStyle = this._bgColor;
   ctx.fillRect (0, 0, this._canvas.width, this._canvas.height);
   
   ctx.lineWidth = 1;
   ctx.strokeStyle = "black";
   for (var i=0;i<active_game.rules.rows;i++){
      for (var j=0;j<active_game.rules.cols;j++){
         R.renderCell(i,j);
      }
   }
}
Renderer.prototype.renderCell = function(row,col){
   var ctx = this._ctx;
   var centerX = this._padding + 30*col;
   var centerY = this._padding + 30*row;
   //var nowRow = row + this.scrolledY % this.game.rules.rows
   if (row>0 || this._wrapY){
      ctx.moveTo(centerX,centerY);
      ctx.lineTo(centerX,centerY-15);
      ctx.stroke();
   }
   if (col>0 || this._wrapX){
      ctx.moveTo(centerX,centerY);
      ctx.lineTo(centerX-15,centerY);
      ctx.stroke();
   }
   if (row<active_game.rules.rows-1 || this._wrapY){
      ctx.moveTo(centerX,centerY);
      ctx.lineTo(centerX,centerY+15);
      ctx.stroke();
   }
   if (col<active_game.rules.cols-1 || this._wrapX){
      ctx.moveTo(centerX,centerY);
      ctx.lineTo(centerX+15,centerY);
      ctx.stroke();
   }
   //$('.result').append('<span>'+col+'</span>');
}
Renderer.prototype.renderStone = function(node, color){
   var ctx = this._ctx;
   
   var match = /^(\d+)-(\d+)$/.exec(node);
   var row = parseInt(match[1]);
   var col = parseInt(match[2]);
   console.debug(row+'|'+col);
   var centerX = this._padding + 30*col;
   var centerY = this._padding + 30*row;
   
   ctx.moveTo(0,0);
   ctx.fillStyle = color == 'w' ? "white" : "black";
   ctx.beginPath();
   ctx.arc(centerX,centerY, 15, 0, Math.PI*2, true);
   ctx.closePath();
   ctx.fill();
}


//note: delta is a hash, indexed by node name.
Renderer.prototype.renderDelta = function(delta){
   var ctx = this._ctx;
   for (var node in delta){
      var change = delta[node];
      var changeType = change.shift();
      if (changeType == 'add'){
         var stoneColor = change[0].stone;
         console.debug('receivedMove: ' + node + ':' + stoneColor);
         this.renderStone(node, stoneColor);
      }
   }
}

function canvas_mousedown_cb(e){
   //e.which = 1 for left, 2 for middle, 3 for right.
   var x = toCanvasX (e);
   var y = toCanvasY (e);
   if (e.which == 1){
      game.attemptMove ('3-3');
   }
}

function canvas_mousemove_cb(e){
   var x = toCanvasX (e);
   var y = toCanvasY (e);
   var foo = '<p>'+x+','+y+'</p>';
   //$('.result').append(foo);
}

/*
 * Get mouse event coordinate converted to canvas coordinate
 * c: The canvas object
 * e: A mouse event
 */
function toCanvasX(e) {
  var posx = 0;

  if (e.pageX)   {
    posx = e.pageX;
  } else if (e.clientX)   {
    posx = e.clientX + document.body.scrollLeft
      + document.documentElement.scrollLeft;
  }
  posx = posx - $("#goban").offset().left;
  return posx;
}

function toCanvasY(e) {
  var posy = 0;

  if (e.pageY)   {
    posy = e.pageY;
  } else if (e.clientY)   {
    posy = e.clientY + document.body.scrollTop
      + document.documentElement.scrollTop;
  }
  posy = posy - $("#goban").offset().top;

  return posy;
}


//cancel with clearInterval(poll_interval);
var poll_interval;

function poll_server(){
   $.ajax({
      url: url_base + "/rt/game",
      data: {
         action: 'ping',
         after: 0,
         gameid: active_game.id,
      },
      dataType: "json",
      type: "POST",
      success: function(data) {
         //$('.result').append(data);
         active_game.post_events (data.after, data.events);
         //alert('Load was performed.');
      }
   });
}

function joined_game_cb (data){
   var ruleset = new Ruleset(data.ruleset.rules.w, data.ruleset.rules.h, "plane", .5, 0);
   active_game = new Game (gameid, ruleset, [1,1]);
   R = new Renderer (active_game);
   
   var C = $('<canvas width="350" height="350" class="board" id="goban"> </canvas>');
   
   $("div.board").append (C);
   R._canvas = C[0];
   R._ctx = R._canvas.getContext("2d");
   //alert(R._canvas.height + ',' +R._canvas.width);
   
   R._canvas.addEventListener('mousemove', canvas_mousemove_cb, false);
   C.mousedown(canvas_mousedown_cb);

   R.renderBoard();
   poll_server();
   setInterval(poll_server, 3000);
}

//join the game.
if (pageType == "game"){
   $(document).ready(function () {
      //tell server we're joining game.
      $.ajax({
         url: url_base + "/rt/game",
         data: {
            action: 'enter_game',
            gameid: gameid,
         },
         dataType: "json",
         type: "POST",
         success: function(data) {
            joined_game_cb (data);
         }
      });
   });
}
