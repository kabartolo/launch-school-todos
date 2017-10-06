$(document).ready(function() {
    $("form.delete").submit(function(event) {
      event.preventDefault();
      event.stopPropagation();
      
      var confirmed = confirm("Are you sure? This cannot be undone!");
      if (confirmed) {
        // this.submit();

        var form = $(this);

        var request = $.ajax({
          url: form.attr("action"), // path for request
          method: form.attr("method") // method for request
        });

        // Executes only when request completes successfully
        request.done(function(data, textStatus, jqXHR) {
          if (jqXHR.status === 204) { // to delete todo
            form.parent("li").remove()
          } else if (jqXHR.status === 200) { // to delete list
            document.location = data; // data here is the url returned by server ('/lists')
          }
        });

        // request.fail(function() {});
      }
    });
});