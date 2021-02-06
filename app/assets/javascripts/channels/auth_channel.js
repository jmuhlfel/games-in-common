(function() {
  const code = (new URLSearchParams(window.location.search)).get('code');

  if (code != undefined) {
    App.auth_sub = App.cable.subscriptions.create({ channel: "AuthChannel", code: code }, {
      received: function(data) {
        $('.pending').addClass('hidden');

        const outcomeClass = data['success'] ? '.success' : '.failure'
        $(outcomeClass).removeClass('hidden')
      },

      rejected: function() {
        $('.pending').addClass('hidden');
        $('.failure').removeClass('hidden')
      }
    })
  }
}).call(this);
