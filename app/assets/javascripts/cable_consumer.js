//= require action_cable
//= require_self
//= require_tree .

(function() {
  this.App = {};
  App.cable = ActionCable.createConsumer();
}).call(this);
