
//Scrolling:

//globals:
//var offset_ew = 0;
//var offset_ns = 0;
var w;
var h;


function scroll (direction){
   var board = document.getElementById('board');
   if (direction=='up'){
      //send top row to bottom
      var row = board.rows[h];
      row.parentNode.insertBefore (row, board.rows[1]);
   }
   else if (direction=='down'){
      var row = board.rows[1];
      row.parentNode.insertBefore (row, board.rows[h+1]);
   }
   else{
	   for(var i = 0; i < h+2; i++){
	      var row = board.rows[i];
	      if (direction=='left'){
            var cell = row.cells[w];
            cell.parentNode.insertBefore (cell, row.cells[1]);
         }
         else{ //right
	         var cell = row.cells[1];
	         cell.parentNode.insertBefore(cell, row.cells[w+1]);
         }
      }
	}
   //msgbox = document.getElementById("msg");
   //msgbox.innerHTML = "blep";
}

function drawPlease (){} //for canvas?


