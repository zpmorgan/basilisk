
var gameid;
var my_side; //if applicable. todo: rethink

//rect vars:
var scrolled_ew = 0;
var scrolled_ns = 0; //up is -
//set these in templates/game/rectboard:
var w;
var h;
var wrap_ns;
var wrap_ew;
var twist_ns;



var board_clickable;
var stones_clickable = 0; //determined by mode: score or move or (view?)
var space_clickable = 0;
var game_running;

var board_position;
var node_modifiers; //highlight, etc

var selectedNode;

//This is handled totally different from the other deltas.
//It's just a proposal. Freeze when you go from present to past.
//Thaw when you go past to present
var future_delta = {};

var num_moves;
var moves; //move history

var chains_loaded = false;
var scoring = false;
//var chains; //array of arrays of nodestrings now stored in var delegates
var delegates; //hash of {delegate=>[chain]}
var delegate_side; //object: 1stnode=>char
var delegate_of_stone; //object: nodestring=>1stnode
var chain_selected; //object: 1stnode=>bool





//these 3 suck:
var selectedNode_original_cell;
var Caleb; //var selectedNode_replacement_cell = too long. so Caleb.
var cell_swap_set_up = 0;
//sucks:
function setup_cell_swap_if_need_be(){
   if (cell_swap_set_up==1){return;} //only do this once
   cell_swap_set_up==1;
   
   var my_stone_img = document.createElement("img");
   my_stone_img.setAttribute('src', img_base + '/' + my_side + "m.gif");
   
   Caleb = document.createElement('td');
      Caleb.setAttribute('id', 'caleb_the_ripper');
      Caleb.appendChild(my_stone_img);
}
//sucks:
function retire_caleb_clone(){
   if (selectedNode_original_cell){
      var caleb_clone = document.getElementById ('caleb_clone');
      if (!caleb_clone)
         return null;
      caleb_clone.parentNode.replaceChild (selectedNode_original_cell, caleb_clone);
      selectedNode_original_cell = null;
   }
}




var shown_move;
var deltas; //not necessary to view
var deltas_loaded;
var deltas_loading=0;
var node_updates = {}; //state of notable nodes at shown_move
var updates_from = 'end'; //'begin' after a jump to the beginning.

function time_jump (direction){
   if (num_moves == 0)
      return;
   if (deltas_loading)
      return;
   if (!deltas_loaded){
      deltas_loading=1;
      $.getJSON(url_base + "/game/" + gameid + "/deltas", 
         function(data){
            deltas = data;
            deltas_loaded = 1;
            deltas_loading=0;
            time_jump(direction);
         }
      );
      return;
   }
   
   if (direction == "bb"){
      if (shown_move==num_moves)
         freeze_future();
      shown_move = 0;
      updates_from = 'begin';
      node_updates = {};
      render_board();
   }
   else if (direction == "ff"){
      shown_move = num_moves;
      updates_from = 'end';
      node_updates = {};
      render_board();
      thaw_future();
   }
   else if (direction == "b"){
      if (shown_move==0)
         return;
      if (shown_move==num_moves)
         freeze_future();
      var delta = deltas[shown_move]; //reverse this one
      apply_delta (delta, 'reverse');
      shown_move--;
   }
   else if (direction == "f"){
      if (shown_move==num_moves)
         return;
      var delta = deltas[shown_move+1];
      apply_delta (delta, 'forward');
      shown_move++;
      if (shown_move==num_moves)
         thaw_future();
   }
}

var stored_button_display; //hide submit button while timetravelling 

function freeze_future(){
   stored_button_display = document.getElementById ('mv_subm_but').style.display;
   document.getElementById ('mv_subm_but').style.display = 'none';
   //remove lastmove highlight, as if it matters..
   //highlight_node (moves[moves.length-1], false);
   if (selectedNode){
      retire_caleb_clone();//sucks 
   }
   else if (scoring){
      for (n in chain_selected){
         //unmark
      }
   }
}
function thaw_future(){
   //restore submit button
   document.getElementById ('mv_subm_but').style.display = stored_button_display;
   highlight_node (moves[moves.length-1], true);
   if (selectedNode){
      select(selectedNode);
   }
   else if (scoring){
      for (n in chain_selected){
         //re-mark
      }
   }
}

function apply_delta (delta, dir){
   for (node in delta){
      var change = delta[node];
      var cell = $("cell_"+node);
      if ((change[0] == 'add'  &&  dir=='forward')  ||  (change[0] == 'remove'  &&  dir=='reverse')){
         //assume that it's a simple stone addition 
         node_updates [node] = {'stone': change[1].stone};
      }
      else if ((change[0] == 'remove'  &&  dir=='forward')  ||  (change[0] == 'add'  &&  dir=='reverse')){
         //assume that it's a simple stone subtraction 
         node_updates [node] = {'stone': 0};
      }
      update_cell (node);
   }
}

//doesnt create td, just modifies it
function update_cell(node){
   var cell = $('#cell_'+node);
   var img = $('#img_'+node);
   var stuff = node_updates [node];
   if (stuff.stone == 0){
      var empty_imgsrc = img_base +'/'+ select_empty_img_from_nodestring (node);
      img.attr ('src', empty_imgsrc);
      if (space_clickable)
         cell.onclick = "select(" +node+ ")";
   }
   else { //new stone on node;
      var imgsrc = img_base +'/'+ stuff.stone + '.gif';
      img.attr ('src', imgsrc);
      if (stones_clickable)
         cell.onclick = "select(" +node+ ")";
   }
}


//decide whether to show moves list & controls.
$(document).ready(function() {
   if (moves.length){
      render_moves_list (moves);
      document.getElementById('moves_pecan').style.display= '';
   }
   else{
      document.getElementById('moves_pecan').style.display= 'none';
   }
});



function select(node){
   if (shown_move != num_moves) //not in the present;
      return;
      
   if (delegate_of_stone[node]){ //clicked on stone;
      select_chain(node);
      return;
   }
   //caleb no longer good
   setup_cell_swap_if_need_be();
   retire_caleb_clone();
   
   var cell = document.getElementById ('cell_' + node);
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

function setup_think_form(){
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

function select_chain(node){
   if (!chains_loaded) return null;
   var delegate_node = delegate_of_stone[node];
   if (delegate_node==null)
      return;
   var chain = delegates[delegate_node];
   
   var imgsrc;
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
      var img = document.getElementById('img_' + chain[n]);
      img.setAttribute('src', imgsrc);
   }
   setup_think_form();
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
      highlight_node (moves[moves.length-1], true);
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
      highlight_node (moves[moves.length-1], true);
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


//this gives a chain the square 'dead' images
function mark_chain(delegate){
   var chain = delegates[delegate]; //(associative)
   var imgsrc = img_base + '/' + delegate_side[delegate] + 'd.gif';
   for (n in chain){
      //alert(n);
      var img = document.getElementById('img_' + chain[n]);
      img.setAttribute('src', imgsrc);
   }
}


//using h,w,wraps_(..),twist_(..),scrolled_(..) 
function render_board(){
   if (typeof (w) == "undefined") return;
   var board_table = document.getElementById ('board');
   if (!board_table) return;
   
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
   
   if (updates_from == 'begin')
      return;
   
   //now highlight whatever needs to be highlighted, such as initially selected as deads
   if (!game_running  ||  !board_clickable  ||  scoring){
      for (d in delegates){
         if (chain_selected[d])
            mark_chain(d);
      }
   }
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
      
      var node = r +'-'+ c;
      row.appendChild (node_cell (node));
      i ++;
   }
   row.appendChild (board_cell ('c'+num+'.gif',null, false));
   return row;
}


//convert node to coordinates, then select empty img
function select_empty_img_from_nodestring(node){
   var co = /^(\d+)-(\d+)$/.exec (node);
   return select_empty_img(co[1],co[2]);
}

//convert node to coordinates, find initial stone or now stone. ignoring updates
function stone_at_node (node){
   var co = /^(\d+)-(\d+)$/.exec (node);
   if (updates_from == 'end')
      return board_position[co[1]][co[2]];
   return initial_board[co[1]][co[2]];
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

function board_cell (img_src){
   var cell  = document.createElement ('td');
   var img = document.createElement ('img');
   img.setAttribute ('src', img_base + "/" + img_src);
   cell.appendChild(img);
   return cell;
}

function node_cell (node){
   var side;
   var imgsrc;
   var updates = node_updates[node];
   if (updates){
      side = updates.stone
   }
   else { 
      side = stone_at_node(node);
   }
   
   if (side != 0){
      clickable = stones_clickable;
      imgsrc = img_base +'/'+ side + '.gif';
   }
   else{ //space
      clickable = space_clickable;
      imgsrc = img_base +'/'+ select_empty_img_from_nodestring(node);
   }
   
   var cell  = document.createElement ('td');
   var img = document.createElement ('img');
   cell.appendChild(img);
   img.setAttribute ('src', imgsrc);
   if (node){
      cell.setAttribute('id', 'cell_'+node);
      img.setAttribute('id', 'img_'+node);
   }
   if (clickable)
      cell.setAttribute('onClick', "select('" + node + "')");
   return cell;
}

function update_node_cell(node){
   var cell = document.getElementById('cell_'+node);
   var img = document.getElementById('img_'+node);
   
}



function switch_mode (mode){
   var submitbutton = document.getElementById ('mv_subm_but');
   var mode_display = document.getElementById ('clicking_mode');
   if (mode=='score'){
      //redraw board with only stones clickable
      scoring=1;
      document.getElementById ('move_mode_button').style.display= '';
      document.getElementById ('score_mode_button').style.display= 'none';
      submitbutton.style.display= '';
      submitbutton.value= 'Submit selection';
      space_clickable = false;
      stones_clickable = true;
      render_board();
      mode_display.innerHTML = "Currently scoring";
      setup_think_form();
      return;
   }
   //else mode=='move'
   //redraw board with only space clickable
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

//apply: if true, highlight. if false, unhighlight 
function highlight_node (move, apply){
   if (!move)
      return;
   var node_pattern = /^\{([^{}]+)\}$/;
   var match_node = node_pattern.exec(move.move);
   if (!match_node) return; //something like 'pass' or 'resign', i guess
   
   var img = document.getElementById ('img_' + match_node[1]);
   if (!img) return; //something wrong
   var special_src = img_base +'/'+ move.side +   (apply ? 'm.gif' : '.gif');
   img.setAttribute('src', special_src);
}


$(document).ready(function() {
   if (!gameid) {return}//something wrong
   
   if (board_clickable && scoring==1)
      stones_clickable = 1;
   if (board_clickable && scoring==0)
      space_clickable = 1;
   
   shown_move = num_moves;
   
   render_board();
   highlight_node (moves[moves.length-1], true);
   if (stones_clickable){
      setup_think_form();
   }
   
   
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



