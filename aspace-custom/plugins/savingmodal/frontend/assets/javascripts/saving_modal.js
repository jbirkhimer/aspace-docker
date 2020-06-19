//
//
//

$(document).ready(function() {

	$.fn.extend({
		
		dialogInt : 0,
		updateCall : function() {
			var updateConsole = function() {
				console.log('Inside new updateConsole function!');
				var smallSaveBttn = $('div.record-toolbar div.pull-left.save-changes button.btn.btn-primary.btn-sm');
				var largeSaveBttn = $('div#archivesSpaceSidebar.sidebar ul.nav.list-group.as-nav-list.affix-top.initialised li.form-actions button.btn.btn-primary');
				var saveButtons = [smallSaveBttn, largeSaveBttn, $('div.row div.col-md-9 div.record-pane div.form-actions button.btn.btn-primary')];
				//var smallSaveBttn = $('button#saveChangesButton');
				
				saveButtons.forEach(function(bttn) {
					console.log('forEach_bttnlength: ' + bttn.length);
				});
				
				if (!smallSaveBttn.length) return;
				if (!saveButtons[0].length) return;
				if (!saveButtons[1].length) return;
				if (!saveButtons[2].length) return;
				
				console.log('Button: ' + smallSaveBttn.attr('modal'));
				
				if(smallSaveBttn.attr('modal')!='enabled') {
					console.log('Modal Not Enabled');
					console.log('Enabling Modal...');
					
					var save = smallSaveBttn;
					
					saveButtons.forEach(function(save) {
					
						save.click( function() {
							console.log("SaveModal Clicked.");
							var savingModal = $(''
							  +'<div class="modal in" id="confirmChangesModal" style="display: block;" aria-hidden="false" tabindex="0">'
							  +'<div class="modal-backdrop  in" style="height: 100%;">'
							  +'</div><div class="modal-dialog"><div class="modal-content"><div class="modal-header">'
							  +'<h3>SAVING IN PROGRESS</h3></div>'
							  +'<div class="modal-body">' //<p><strong>Your changes are being saved to the server.</strong></p>'
							  +'<p>Please wait...</p>'
							  +'<br/><img src="/assets/icons/circles.svg"><br/>'
							  +'</div><div class="modal-footer">'
							  +'</div></div></div></div>'
							  +'');
							var savingModal = $(''
									  +'<div class="modal in" id="confirmChangesModal" style="display: block;" aria-hidden="false" tabindex="0">'
									  +'<div class="modal-backdrop  in" style="height: 100%;"></div>'
									  +'<div style="display:table;position:absolute;height:100%;width:100%;">'
									  +'	<div style="display:table-cell;vertical-align:middle;width:100%;text-align:center;">'
									  +'		<div style="margin:0 auto;display:inline-block;">'
//									  +'			<img src="/assets/icons/circles.svg">'
									  +'			<div class="spinner" style="font-size: 50px; display: inline; z-index: 2500; position: fixed; margin: 0px; left: 50%; top: 50%;"></div>'
									  +'			<div class="spinner" style="font-size: 50px; display: inline; z-index: 2500; position: fixed; margin: 0px; left: 50%; top: 50%;"></div>'
									  +'		</div>'
									  +'	</div>'
									  +'</div></div>'
									  +'');
							savingModal.appendTo( $('body') );
							var redraw = $('div#confirmChangesModal').toggle().toggle();
							//var smallSaveBttn = $('div.record-toolbar div.pull-left.save-changes button.btn.btn-primary.btn-sm');
							save.attr('startDate', Date.now());
							var dialogInt =	window.setInterval( function() {
								console.log('in ClickInterval...');
								//var smallSaveBttn = $('div.record-toolbar div.pull-left.save-changes button.btn.btn-primary.btn-sm');
								console.log('startDate: ' + save.attr('startDate'));
								console.log(parseInt(save.attr('startDate'))+1000);
								console.log(Date.now());
								if(parseInt(save.attr('startDate'))+1000 > Date.now()) {
									console.log('Inside Delay' + dialogInt);
									var i = Date.now();
								} else {
									console.log('Clearing Interval');
									window.clearInterval(save.attr('intervalID'));
									window.clearInterval(dialogInt);
								}
								
							}, 250);
							save.attr('intervalID', dialogInt);
						});

					});


//					smallSaveBttn.click( function() {
//						var delayed = window.setTimeout( function() {
//						  var redraw = $('div#confirmChangesModal').toggle().toggle();
//						  console.log("SaveTime Clicked.");
//						  console.log(Date.now());
//						  for(var i = Date.now(); i+5000 > Date.now(); i) {
//							  i = i;
//						  }
//						  console.log(Date.now());
//						}, 100);
//					  });
//

					smallSaveBttn.attr('modal','enabled');
					console.log('Done Enabling Modal.');
				} else {
					console.log('Modal Enabled!!');
				}

			}

			$(document).ajaxStart(function() {
			});
			
			$(document).ajaxStop(function() {
				updateConsole();
				if(($('div#tree-container').length != 0) && $('div#confirmChangesModal').length) {
					console.log('Removing Modal...');
					$('div#confirmChangesModal').remove();
				}
			});
			
			$( document ).ajaxComplete(function( event, xhr, settings ) {
				updateConsole();
				console.log('ajaxComplete: ' + xhr.status);
			});

			updateConsole();
		}

	});

	console.log('Saving_modal fn.extend!');
	$(document).updateCall();
	
});


//