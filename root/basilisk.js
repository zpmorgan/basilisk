
//Scrolling:

//globals:
//var offset_ew = 0;
//var offset_ns = 0;
var img_base;
var url_base;
var gameid;
var side;
var w;
var h;
var selectedNode;
var selectedNode_original_cell;
var Caleb; //var selectedNode_replacement_cell = too long. so Caleb.

var cell_swap_set_up = 0;
function setup_cell_swap_if_need_be(){
   if (cell_swap_set_up==1){return;} //only do this once
   cell_swap_set_up==1;
   
   var my_stone_img = document.createElement("img");
   my_stone_img.setAttribute('src', img_base + '/' + side + "m.gif");
   
   Caleb = document.createElement('td');
      Caleb.setAttribute('id', 'caleb_the_ripper');
      Caleb.appendChild(my_stone_img);
}

function select(node){ //selectnode
   setup_cell_swap_if_need_be();
   if (selectedNode_original_cell){
      var caleb_clone = document.getElementById ('caleb_clone');
      caleb_clone.parentNode.replaceChild (selectedNode_original_cell, caleb_clone);
   }
   var cell = document.getElementById (node);
   selectedNode_original_cell = cell.cloneNode(true);
   var caleb_clone = Caleb.cloneNode(true);
   caleb_clone.setAttribute('id', 'caleb_clone');
   cell.parentNode.replaceChild (caleb_clone, cell);
   
   //set form element for submission
   selectedNode = node; //string, such as '4-2'
   var submit_form = document.getElementById ('move_submit_form');
   submit_form.setAttribute ('action', url_base +'/game/' + gameid + '/move/'+ selectedNode);
   document.getElementById ('mv_subm_but').style.display='';
}

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


