
var scrolled_ew = 0;
var scrolled_ns = 0; //up is -
var stones_clickable = 0; //determined by mode: score or move or (view?)
var space_clickable = 0;

var selectedNode;
var selectedNode_original_cell;
var Caleb; //var selectedNode_replacement_cell = too long. so Caleb.

var moves; //move history

var cell_swap_set_up = 0;

var chains_loaded = false;
var scoring = false;
//var chains; //array of arrays of nodestrings
var delegates; //hash of {delegate=>[chain]}
var delegate_side; //object: 1stnode=>char
var delegate_of_stone; //object: nodestring=>1stnode
var chain_selected; //object: 1stnode=>bool

function setup_cell_swap_if_need_be(){
   if (cell_swap_set_up==1){return;} //only do this once
   cell_swap_set_up==1;
   
   var my_stone_img = document.createElement("img");
   my_stone_img.setAttribute('src', img_base + '/' + side + "m.gif");
   
   Caleb = document.createElement('td');
      Caleb.setAttribute('id', 'caleb_the_ripper');
      Caleb.appendChild(my_stone_img);
}
function retire_caleb_clone(){
   if (selectedNode_original_cell){
      var caleb_clone = document.getElementById ('caleb_clone');
      if (!caleb_clone)
         return null;
      caleb_clone.parentNode.replaceChild (selectedNode_original_cell, caleb_clone);
      selectedNode_original_cell = null;
   }
}

function select(node){
   if (delegate_of_stone[node]){
      select_chain(node);
      return;
   }
   //caleb no longer good
   setup_cell_swap_if_need_be();
   retire_caleb_clone();
   
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
   document.getElementById ('mv_subm_but').value= 'Submit move';
}

$(document).ready(function() {
   if (!gameid) {return;}
   //TODO: make these work.
   //document.getElementById ('resign_button').onClick = "select_resign();return false;";
   //document.getElementById ('pass_button').onClick = "select_pass();return false;";
});
function select_resign(){ //prepares same submit button as submit()
   retire_caleb_clone();
   var submit_form = document.getElementById ('move_submit_form');
   submit_form.setAttribute ('action', url_base +'/game/' + gameid + '/resign');
   document.getElementById ('mv_subm_but').style.display= '';
   document.getElementById ('mv_subm_but').value= 'Submit resignation';
}
function select_pass(){ //prepares same submit button as submit()
   retire_caleb_clone();
   var submit_form = document.getElementById ('move_submit_form');
   submit_form.setAttribute ('action', url_base +'/game/' + gameid + '/pass');
   document.getElementById ('mv_subm_but').style.display= '';
   document.getElementById ('mv_subm_but').value= 'Submit pass';
}


function select_chain(node){
   if (!chains_loaded) return null;
   var delegate_node = delegate_of_stone[node];
   if (delegate_node==null)
      return;
   var chain = delegates[delegate_node];
   
   var imgfile;
   if (chain_selected[delegate_node]){
      chain_selected[delegate_node] = 0; // deselect
      imgsrc = img_base + '/' + delegate_side[delegate_node] + '.gif';
   }
   else{
      chain_selected[delegate_node] = 1; // select
      imgsrc = img_base + '/' + delegate_side[delegate_node] + 'd.gif';
   }
   
   //alert(chain);
   for (n in chain){
      //alert(n);
      var img = document.getElementById('img ' + chain[n]);
      img.setAttribute('src', imgsrc);
   }
   //adjust action for submit form:
   var action = "";
   for (d in delegates){
      if (!chain_selected[d]) continue;
      if (!action=='') action += '_'; //separator
      action += d;
   }
   var submit_form = document.getElementById ('move_submit_form');
   submit_form.setAttribute ('action', url_base +'/game/' + gameid + '/think/' + action);
   var submit_but = document.getElementById ('mv_subm_but');
   submit_but.style.display= '';
   submit_but.value= 'Submit selection';
}



function scroll (direction){
   var board = document.getElementById('board');
   var tbody = board.tBodies[0];
   if (direction=='up'){
      scrolled_ns += (h*2)-1;
      scrolled_ns %= (h*2);
      var row = board.rows[h];
      row.parentNode.removeChild (row);
      if (twist_ns){
         var i=0;
         var r = (i + scrolled_ns);
         r %= (h*2);
         if ((r >= h) && twist_ns)
            row = board_row (r, 'reverse');
         else
            row = board_row (r, 'forward');
      }
      tbody.insertBefore (row, board.rows[1]);
      highlight_node (moves[moves.length-1]);
   }
   else if (direction=='down'){
      scrolled_ns ++;
      scrolled_ns %= (h*2);
      var row = board.rows[1];
      row.parentNode.removeChild (row);
      if (twist_ns){
         var i=h-1;
         var r = (i + scrolled_ns);
         r %= (h*2);
         if ((r >= h) && twist_ns)
            row = board_row (r, 'reverse');
         else
            row = board_row (r, 'forward');
      }
      tbody.insertBefore (row, board.rows[h]);
      highlight_node (moves[moves.length-1]);
   }
   else {
      if (direction=='left'){
         scrolled_ew += w-1;
         scrolled_ew %= w;
      }
      else{ //right
         scrolled_ew ++;
         scrolled_ew %= w;
      }
      for(var i = 0; i < h+2; i++){ //shift each row l or r
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


//using h,w,wraps_(..),twist_(..),scrolled_(..) 
function render_board(){
   if (typeof (w) == "undefined") return;
   var board_table = document.getElementById ('board');
   if (!board_table) return;
   //clearTimeout(tomato);
   
   var old_tbody = document.getElementById ('board_tbody');
   if (old_tbody)  board_table.removeChild (old_tbody);
   
   var new_tbody = document.createElement ('tbody');
   new_tbody.setAttribute ('id', 'board_tbody');
   
   new_tbody.appendChild (board_letter_row('forwards'));
   var i=0;
   while (i<h){
      var r = (i + scrolled_ns);
      r %= (h*2);
      var row;
      if ((r >= h) && twist_ns)
         row = board_row (r, 'reverse');
      else
         row = board_row (r, 'forward');
      new_tbody.appendChild (row);
      i++
   }
   new_tbody.appendChild (board_letter_row (twist_ns ?'reverse' : 'forward'));
   board_table.appendChild(new_tbody);
}

function board_row (r, direction){
   r %= h;
   var row = document.createElement ('tr');
   var num = h - r;
   row.appendChild (board_cell ('c'+num+'.gif',null, false));
   
   var i=0;
   while (i<w) {
      var c = i + scrolled_ew;
      c %= w;
      if (direction=='reverse')
         c = w-c-1;
      var stone = board_position[r][c];
      var img;
      
      clickable = stones_clickable;
      if (stone == 0){
         img = 'e.gif';
         img = select_empty_img(r,c);
         clickable = space_clickable;
      }
      else
         img = stone + '.gif';
      var node = r +'-'+ c;
      row.appendChild (board_cell (img,node, clickable));
      i ++;
   }
   row.appendChild (board_cell ('c'+num+'.gif',null, false));
   return row;
}

//find dgs-style filename for empty cells
function select_empty_img(row,col){
   var Ektah;
   if (wrap_ns || twist_ns){
      Ektah = 'e';
   }
   else {
      if (row==0) {Ektah = 'u'}
      else if (row==h-1) {Ektah = 'd'}
      else {Ektah = 'e'}
   }
   if (!wrap_ew){ // decide how side should be oriented in case of twisting
      if (col==0) {
         if (twist_ns){
            if ((scrolled_ns + h-row-1) % (2*h) < h) Ektah += 'l';
            else Ektah += 'r';
         }
         else
            Ektah += 'l';
      }
      else if (col==w-1) {
         if (twist_ns){
            if ((scrolled_ns + h-row-1) % (2*h) < h) Ektah += 'r';
            else Ektah += 'l';
         }
         else
            Ektah += 'r';
      }
   }
   return Ektah + '.gif';
}


//skip i
var letters = ['a','b','c','d','e','f','g','h','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z'];

function board_letter_row (direction){
   var row = document.createElement ('tr');
   
   var blank_cell = board_cell ('blank.gif',null, false);
   blank_cell.firstChild.setAttribute ('height', 25);
   blank_cell.firstChild.setAttribute ('width', 31);
   row.appendChild (blank_cell);
   
   var i=0;
   while (i<w) {
      var col = i + scrolled_ew;
      col %= w;
      if (direction=='reverse')
         col = w-col-1;
      row.appendChild (board_cell ('c'+letters[col]+'.gif',null, false));
      i ++;
   }
   
   row.appendChild (blank_cell.cloneNode(true));
   return row;
}
function board_cell (img_src, node, clickable){
   var cell  = document.createElement ('td');
   var img = document.createElement ('img');
   img.setAttribute ('src', img_base + "/" + img_src);
   cell.appendChild(img);
   if (node){
      cell.setAttribute('id', 'cell '+node);
      img.setAttribute('id', 'img '+node);
   }
   if (clickable)
      cell.setAttribute('onClick', "select('" + node + "')");
   return cell;
}

function switch_mode (mode){
   var submitbutton = document.getElementById ('mv_subm_but');
   var mode_display = document.getElementById ('clicking_mode');
   if (mode=='score'){
      if (scoring==1)
         ;//return;
      document.getElementById ('move_mode_button').style.display= '';
      document.getElementById ('score_mode_button').style.display= 'none';
      scoring=1;
      submitbutton.style.display= '';
      space_clickable = false;
      stones_clickable = true;
      render_board();
      mode_display.innerHTML = "Currently scoring";
      return;
   }
   //else mode=='move'
   if (scoring == 0)
     ;// return;
   document.getElementById ('move_mode_button').style.display= 'none';
   document.getElementById ('score_mode_button').style.display= '';
   scoring=0;
   submitbutton.style.display= 'none';
   submitbutton.value= 'Submit selection';
   space_clickable = true;
   stones_clickable = false;
   render_board();
   mode_display.innerHTML = "Currently moving";
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
      //var move    = moves[i].move;
      var move    = moves[i].pretty_node;
      var side    = moves[i].side;
      var movenum = moves[i].movenum;
      var option = new Option (movenum +": "+ side +', '+ move, movenum);
      moves_select.add (option, null);
   }
}

function highlight_node (move){
   var node_pattern = /^\{([^{}]+)\}$/;
   var match_node = node_pattern.exec(move.move);
   if (!match_node) return; //something like 'pass' or 'resign', i guess
   
   var img = document.getElementById ('img ' + match_node[1]);
   if (!img) return; //something wrong
   var special_src = img_base +'/'+ move.side + 'm.gif';
   img.setAttribute('src', special_src);
}

$(document).ready(function() {
   if (!gameid) {return}//something wrong
   
   if (board_clickable && scoring==1)
      stones_clickable = 1;
   if (board_clickable && scoring==0)
      space_clickable = 1;
   
   render_board();
   
   //dl & display move list
   $.getJSON ( url_base +"/game/"+ gameid +"/allmoves",
      function (data) {
         if (data[0] == 'success'){
            moves = data[1];
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



