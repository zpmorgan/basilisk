//This is for proposal_gui tabbed control panel
//uses jquery UI for tabs and sliders.


//set up tabs & slider signals & checkbox signals
$(document).ready(function(){
   $("#tabs").tabs();
   $(".randslide").slider({min: 0, max: 1, step: .05});
   
   //HeisenGo chance slider. excludes schroedingo.
   $("#hg_slider").bind('slidechange', function(event, ui) {
      var chance = point05_nearest (ui.value)
      $('#heisengo_checkbox').attr('checked', (chance>0) ? true : false);
      if (chance){
         $('#schroedingo_checkbox').attr('checked', false);
      }
      setPercentLabels();
   });
   
   //PlanckGo chance slider
   $("#pg_slider").bind('slidechange', function(event, ui) {
      var chance = point05_nearest (ui.value)
      $('#planckgo_checkbox').attr('checked', (chance>0) ? true : false);
      setPercentLabels();
   });
   
   //callbacks for randomness checkboxes
   
   $('#heisengo_checkbox').click( function(){
      var czeched = $(this).is(":checked");
      if(czeched){ //exclude schroedingo
         $('#schroedingo_checkbox').attr('checked', false);
         $('#hg_slider').slider('option', 'value', 1);
      }
      else{
         $('#hg_slider').slider('option', 'value', 0);
      }
      setPercentLabels();
   });
   $('#schroedingo_checkbox').click( function(){
      var czeched = $(this).is(":checked");
      if(czeched){ //exclude heisengo
         $('#hg_slider').slider('option', 'value', 0);
         $('#heisengo_checkbox').attr('checked', false);
      }
      else{
      }
      setPercentLabels();
   });
   $('#planckgo_checkbox').click( function(){
      var czeched = $(this).is(":checked");
      if(czeched){
         $('#pg_slider').slider('option', 'value', 1);
      }
      else{
         $('#pg_slider').slider('option', 'value', 0);
      }
      setPercentLabels();
   });
});


//now set sliders to form-hidden chance values
$(document).ready(function(){
   var hg_chance = $('#hg_chance').val();
   var pg_chance = $('#pg_chance').val();
   $('#hg_slider').slider('option', 'value', hg_chance);
   $('#pg_slider').slider('option', 'value', pg_chance);
   setPercentLabels();
   
   $("#dialog").dialog({ autoOpen: false });
});

function setPercentLabels(){
   var hg_chance = point05_nearest ($('#hg_slider').slider('option','value'));
   var pg_chance = point05_nearest ($('#pg_slider').slider('option','value'));
   $('#hg_value_label').text(toPercent(hg_chance));
   $('#pg_value_label').text(toPercent(pg_chance));
   //also set corresponding hidden form elements
   $('#hg_chance').val(hg_chance);
   $('#pg_chance').val(pg_chance);
}

//round to nearest .01 really
function point05_nearest(value){
   value = parseFloat(value);
   var ju = value.toFixed(2);
   return ju;
}
//
function toPercent(value){
   var brak = value*100;
   return brak.toFixed(0) + '%';
}
