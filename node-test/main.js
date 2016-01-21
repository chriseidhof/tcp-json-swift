var jot = require('json-over-tcp');

// Creates one connection to the server when the server starts listening
function createConnection(){
  // Start a connection to the server
  var socket = jot.connect(2015, function(){
    // Send the initial message once connected
    var message = { "title" : "", "height" : 500, "root" : { "items" : [ { "title" : "Test 1", "type" : "label", "id": "one" }, { "text" : "Test 2", "type" : "text", "editable": true, "id": "two" }, { "title" : "Test 3", "type" : "button", "id": "three" } ], "direction" : "vertical", "type" : "stack" }, "width" : 200, "type" : "window" }
    socket.write(message);
  });

  // Whenever the server sends us an object...
  socket.on('data', function(data){
    // Output the answer property of the server's message to the console
    console.log("Server's answer:");
    console.log(data);

    if(data.receiver == 'three' && data.type == 'click') {
      console.log({ type: 'get', 'id': 'two', 'property': 'text'});
      socket.write({ type: 'get', 'id': 'two', 'property': 'text'});
    }
    if(data.receiver == 'two' && data.type == 'value' && data.property == 'text') {
      var theText = data.value;
      console.log('print')
      theText += "\nAnd a new line";
      socket.write({ type: 'set', 'id': 'two', 'property': 'text', 'value': theText});
    }
  });
}

createConnection();
