// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or vendor/assets/javascripts of plugins, if any, can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// the compiled file.
//
// WARNING: THE FIRST BLANK LINE MARKS THE END OF WHAT'S TO BE PROCESSED, ANY BLANK LINE SHOULD
// GO AFTER THE REQUIRES BELOW.
//
//= require jquery
//= require jquery_ujs
//= require twitter/bootstrap
//= require best_in_place
//= require dataTables/jquery.dataTables
//= require dataTables/bootstrap/3/jquery.dataTables.bootstrap
//= require_tree .

function toggleOverlay( popDialogName ){
  var overlay = document.getElementById('overlay');
  //var specialBox = document.getElementById('specialBox');
  var specialBox = document.getElementById(popDialogName);
  overlay.style.opacity = .8;
  if(overlay.style.display == "block"){
    overlay.style.display = "none";
    specialBox.style.display = "none";
  } else {
    overlay.style.display = "block";
    specialBox.style.display = "block";
  }
}

function selectCustomer(elemid){
  var trid;
  trid = elemid.id;
  alert(trid);
  toggleOverlay('customerListBox');
}

$(document).ready(function() {
  /* Activating Best In Place */
  jQuery(".best_in_place").best_in_place();

  $('#items').dataTable({
    "sPaginationType": "bootstrap"
  });

  $('#customers').dataTable({
    "sPaginationType": "bootstrap"
  });

  $('#contacts').dataTable({
    "sPaginationType": "bootstrap"
  });

  $('#opportunities').dataTable({
    "sPaginationType": "bootstrap"
  });
});
