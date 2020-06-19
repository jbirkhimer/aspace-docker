function waitToExecute(){
    if (!jQuery(".alert-error pre").size()) {
      window.requestAnimationFrame(waitToExecute);
    }else {
       if(jQuery(".alert-error p").text() == "An error occurred saving this record."){
       	jQuery(".alert-error pre").text('A valid EAD ID is required in order to create child resources.');
       }

     }
};

waitToExecute();