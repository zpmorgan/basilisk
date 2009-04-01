
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
   var cell = document.getElementById ('cell ' + node);
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

function reverse_stone_row(row){
   //alert(row.childNodes.length);
   var nodes = row.childNodes;
   
   //let's remove text elements
   var j = 0;
   while (j < nodes.length) {
      if (nodes[j].nodeType != 1)
         row.removeChild(nodes[j]);
      j++;
   }
   
   var cells = new Array;
   while (row.hasChildNodes()){
      cells.push(row.firstChild)
      row.removeChild(row.firstChild)
   }
   cells.reverse();
   for (i in cells){
      row.appendChild (cells[i]);
   }
}
function scroll (direction){
   var board = document.getElementById('board');
   if (direction=='up'){
      //send top row to bottom
      var row = board.rows[h];
      if (twist_ns)
         reverse_stone_row(row);
      row.parentNode.insertBefore (row, board.rows[1]);
   }
   else if (direction=='down'){
      var row = board.rows[1];
      if (twist_ns)
         reverse_stone_row(row);
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
}


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
   c_table.replaceChild (comment_tbody, c_table.tBodies[0]);
   if (logged_in){
      //clear comment textfield, msg on successful comment
      var comment_field = document.getElementById("Leocorno");
      comment_field.value= "";
      var comment_badness = document.getElementById("cBadness");
      comment_badness.innerHTML = "";
   }
}

//appends moves to empty <select>, and highlights latest move.
function render_moves_list (moves){
   var moves_select = document.getElementById('moves_select');
   for (i in moves){
      var move    = moves[i].move;
      var side    = moves[i].side;
      var movenum = moves[i].movenum;
      var option = new Option (movenum +": "+ side +' '+ move, movenum);
      moves_select.add (option, null);
   }
}

function highlight_node (move){
   var node_pattern = /^\{([^{}]+)\}$/;
   var match_node = node_pattern.exec(move.move);
   if (!match_node) return; //something like 'pass' or 'resign', i guess
   
   var img = document.getElementById ('img ' + match_node[1]);
   var special_src = img_base +'/'+ move.side + 'm.gif';
   img.setAttribute('src', special_src);
}

//do stuff for /game/id
$(document).ready(function() {
   if (!gameid) {return}
   //dl & display comments
   $.getJSON (
      url_base +"/comments/"+ gameid,
      function (data) {render_comment_table(data[1])}
      //data is ['success', game_comments]
   );
   
   //dl & display move list
   $.getJSON ( url_base +"/game/"+ gameid +"/allmoves",
      function (data) {
         if (data[0] == 'success'){
            var moves = data[1];
            if (moves.length){
               render_moves_list (moves);
               highlight_node (moves[moves.length-1]);
               document.getElementById('moves_pecan').style.display= '';
            }
            else{
               document.getElementById('moves_pecan').style.display= 'none';
            }
         }
         else
            alert (data[0]);
      }
      //data is ['success', game_moves]
   );
   
   //set up comment submission form
   //by binding 'new_comment' form and provide a simple callback function 
   $('#new_comment').ajaxForm(function(json, success, object) { 
      var msg_plus_data = eval ('('+json+')');
      var msg = msg_plus_data [0];
      if (msg == 'success'){
         var comments_data = msg_plus_data[1];
         render_comment_table (comments_data);
         return;
      }
      //failure
      var comment_badness = document.getElementById("cBadness");
      comment_badness.innerHTML = msg;
   }); 
}); 
