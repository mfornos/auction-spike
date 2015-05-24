# Auction Spike

[Vibe.d](http://vibed.org/) proof of concept service that delivers Dutch Auctions over WebSockets.

## Requirements

* [DMD](http://dlang.org/download.html) - The D programming language compiler
* [DUB](http://code.dlang.org/download) - The D build tool

## Running

1. Clone this repository: ```git clone https://github.com/mfornos/auction-spike.git```
2. In the root folder, run: ```dub```

You will get the following output:

```
Listening for HTTP requests on 127.0.0.1:8080
Auction started (2015-May-24 18:40:51.037055)
Please open http://127.0.0.1:8080/ in your browser.
```

Now you can browse the service (one bidder per browser tab) and start bidding.
