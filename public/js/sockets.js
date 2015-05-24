/**
  Auctions websocket client.

  Part of the web-based auctions proof of concept.
*/
$(function() {

  var socket;

  function connect() {
    setStatus('connecting...');
    socket = new WebSocket(getBaseURL() + '/auction');
    socket.onopen = function() {
      setStatus('connected. exchanging token...');
      socket.send('tok_' + Math.random().toString(16).slice(2));
    }
    socket.onmessage = function(message) {
      setStatus('connected.');

      var data = JSON.parse(message.data);
      updateAuctionInfo(data);

      if ('win' == data.op) {
        win(data);
      } else if ('closed' == data.status) {
        closed(data);
      } else {
        updatePrice(data);
        enableAction();
      }
    }
    socket.onclose = function() {
      setStatus('connection closed.');
    }
    socket.onerror = function() {
      setStatus('Error!');
    }
  }

  function updatePrice(json) {
    $('#price').fadeOut(function() {
      $(this).text(json.price).fadeIn();
    });
  }

  function win(json) {
    end(json, 'Congratulations, you win!', 'glyphicon-thumbs-up', 'bg-success');
  }

  function closed(json) {
    end(json, 'Auction closed, better luck next time!', 'glyphicon-info-sign', 'bg-warning');
  }

  function end(json, msg, ico, bg) {
    $('#price').text(json.price);
    $('#outcome').text(msg);
    $('.lead .glyphicon').addClass(ico);
    $('.lead').addClass(bg).fadeIn();
    disableAction();
  }

  function updateAuctionInfo(json) {
    $('#item').text(json.item);
    $('#item-desc').text(json.description);
    $('#bidders').text(json.bidders);
    $('#auction-status').text(json.status);
  }

  function enableAction() {
    $('#accept-bid').removeClass('disabled');
  }

  function disableAction() {
    $('#accept-bid').addClass('disabled');
  }

  function closeConnection() {
    socket.close();
    setStatus('closed.');
  }

  function setStatus(text) {
    $('#connection-status').text(text);
  }

  function getBaseURL() {
    var href = window.location.href.substring(7); // strip 'http://'
    var idx = href.indexOf('/');
    return 'ws://' + href.substring(0, idx);
  }

  function init() {
    $('#accept-bid').click(function(e) {
      e.preventDefault();
      socket.send('ack');
      disableAction();
    });
    $('#disconnect').click(closeConnection);
  }

  init();
  connect();

});
