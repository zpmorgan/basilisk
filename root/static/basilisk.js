


function Ruleset(){
   this.rows = 6;
   this.cols = 6;
   this.topology = 'plane';
   this.komi = 6.5;
   this.handi = 0;
}

function Game(rules, players)
{
    this.rules = rules;
    this.players = players;
}

var active_game;

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
R = new Renderer (active_game);

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
}


var timeout;

function poll_server(){
   $.ajax({
      dataType: "json",
      type: "POST",
      success: function(data) {
         $('.result').prepend(data);
         //alert('Load was performed.');
      }

   });
   timeout = setTimeout("poll_server{};" ,1000);
}



if (pageType == "game"){
   $(document).ready(function () {
      
      active_game = new Game(new Ruleset(), [1,1]);
      
      R._canvas = document.createElement("canvas");
      R._canvas.width = R._canvas.height = 350;
      $("div.board").append(R._canvas);
      //alert(R.canvas);
      R._ctx = R._canvas.getContext("2d");
      //alert(R._canvas.height + ',' +R._canvas.width);
      
      R.renderBoard();
   });
}
