/** Copyright: Public Domain */

import vibe.core.log;
import vibe.http.fileserver : serveStaticFiles;
import vibe.http.router : URLRouter;
import vibe.http.server;
import vibe.http.websockets : handleWebSockets;

import auction;

/** Auctions Spike

    Vibe.d proof of concept service that delivers Dutch Auctions over WebSockets.
 */
shared static this()
{
    auto auction = new Auction;
    auto router = new URLRouter;
    router.get("/", &index);
    router.get("/auction", handleWebSockets(&auction.connect));
    router.get("*", serveStaticFiles("public/"));

    auto settings = new HTTPServerSettings;
    settings.port = 8080;
    settings.bindAddresses = ["::1", "127.0.0.1"];
    listenHTTP(settings, router);

    auction.start();

    logInfo("Please open http://127.0.0.1:8080/ in your browser.");
}

void index(HTTPServerRequest req, HTTPServerResponse res)
{
    res.render!("main.dt", req);
}
