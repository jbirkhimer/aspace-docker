
//function GetURLParameter(sParam) {
//  var sPageURL = window.location.search.substring(1);
//  var sURLVariables = sPageURL.split('&');
//  for (var i = 0; i < sURLVariables.length; i++)
//  {
//    var sParameterName = sURLVariables[i].split('=');
//    if (sParameterName[0] == encodeURIComponent(sParam))
//    {
//        return sParameterName[1];
//    }
//  }
//}


$(document).ready(function() {

  console.log("Running CSV plugin interface code");

  // Cleanup interface: Replaces SI branding; Removes external AS footer link.
  //var icon = $('nav.navbar.navbar-default ul.nav.navbar-nav li a')[0];
  //icon.innerHTML = ('<img src="https://www.si.edu/favicon.ico" width="50%">');
  //$('html div.container-fluid.center-block header h1').remove();
  //$('footer div.container.footer p a').attr('href', 'javascript:void(0);');

  // Create new CSV download menu button
  if(window.location.pathname.match(/search/)) {
	  var newBtn = $(''
		+ '<div class="btn btn-inline-form"> '
		+ '<a class="btn btn-sm btn-default dropdown-toggle" data-toggle="dropdown" '
		+ 'href="javascript:void(0);" aria-expanded="false">'
		+ ' CSV Downloads '
		+ '<span class="caret"></span> '
		+ '</a>'
		+ '<ul class="dropdown-menu open-aligned-right"> '
		+ '<li> <a id="optionOne" href="javascript:void(0);"> Work Order CSV Download </a> </li> '
		+ '<li> <a id="optionTwo" href="javascript:void(0);"> Pull List CSV Download </a> </li> '
		+ '</ul>'
		+ '</div>');
	
	  var downloadBtn = $('.record-toolbar a#searchExport');
	  newBtn.insertAfter( downloadBtn );
	  //$('li a#optionOne').attr('href', downloadBtn.attr('href'));
	  $('li a#optionOne').attr('href', '/plugins/drmtest/gen?'+window.location.search.substring(1)+'&source='+window.location.pathname+'&style=work');
	  $('li a#optionTwo').attr('href', '/plugins/drmtest/gen?'+window.location.search.substring(1)+'&source='+window.location.pathname+'&style=pull');
  }
  
  // Removes existing CSV download button
  var downloadBtn = $('.record-toolbar a#searchExport');
  downloadBtn.remove();


  //  if (!window.location.pathname.match(/search/)) {
//	  console.log('matched search!');
//	  newBtn.remove();
//  }

});
