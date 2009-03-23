
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

// populate comments
function render_comment_table(data){
   var c_table = document.getElementById("comments_table");
   var comment_tbody = document.createElement("tbody");
   if (data.length == 0) {
      comment_tbody.innerHTML = "<tr><td> No comments. </td></tr>";
   }
   else{
      var head_row = document.createElement("tr");
      var cell = document.createElement("td");
      //head_row.innerHTML = "<td>#</td><td>comment</td>";
      cell.innerHTML = '#';
      head_row.appendChild(cell);cell = document.createElement("td");
      cell.innerHTML = 'comment';
      head_row.appendChild(cell);
      head_row.setAttribute('class', 'headrow');
      comment_tbody.appendChild (head_row);
      for (i in data){
         var c_row = document.createElement("tr");
         cell = document.createElement("td");
         cell.innerHTML = data[i].movenum;
         c_row.appendChild(cell);
         cell = document.createElement("td");
         cell.innerHTML = "<b>"+ data[i].commentator +'</b>: ' + data[i].comment;
         c_row.appendChild(cell);
         comment_tbody.appendChild (c_row);
      }
   }
   c_table.replaceChild (comment_tbody, c_table.tBodies[0])
   //alert(data);
}

//set up comment submission form
$(document).ready(function() { 
   // bind 'new_comment' form and provide a simple callback function 
   if (!gameid) {return}
   $('#new_comment').ajaxForm(function(json, success, object) { 
      var comments_data = eval('('+json+')');
      render_comment_table (comments_data);
      //alert("Thank you for your comment!" + json);
   }); 
});

//dl & display comments
$(document).ready(function() {
   if (!gameid) {return}
   var comments = $.getJSON (
         url_base +"/comments/"+ gameid,
         function (data) {render_comment_table(data)}
   );
}); 
