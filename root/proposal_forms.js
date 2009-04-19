
function hide_heisengo_controls(){
   var fset = document.getElementById('heisengo_fields');
   fset.style.display="none";
}
function show_heisengo_controls(){
   var fset = document.getElementById ("heisengo_fields");
   fset.style.display="";
}
function heisenClicked(checkbox) {
   if (checkbox.checked)
      show_heisengo_controls();
   else
      hide_heisengo_controls();
}


$(document).ready(function() {
   var heisenBox = document.getElementById('heisengo_checkbox');
   heisenClicked(heisenBox);
   heisenBox.setAttribute ('onClick', "heisenClicked(this);");
});
