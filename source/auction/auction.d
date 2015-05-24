/** Copyright: Public Domain */

module auction;

import vibe.core.core;
import vibe.core.log;
import vibe.core.concurrency : send, receiveOnly;
import vibe.http.websockets;
import vibe.data.json;

import core.time;
import std.functional;
import std.datetime;
import std.stdio;
import std.string;

/** Represents a Dutch Auction delivered over WebSockets.

   A Dutch Auction is a type of auction in which the price on an item is lowered until it gets a bid.
   The first bid made is the winning bid and results in a sale, assuming that the price is above
   the reserve price.
 */
class Auction {

/** Default auction parameters */
static struct Params
{
    string item = "B1002:ASA5500";
    string description = "The Cisco ® ASA 5500 Series Business Edition is an enterprise-strength
       comprehensive security solution that combines market-leading firewall,
       VPN, and optional content security capabilities, so you can feel confident
       your business is protected.";
    float startPrice = 650.50;
    float reservePrice = 340.00;
    float delta = 0.50;
    Duration frequency = 2.seconds;
    int maxBidders = 10000;
};

this()
{
    m_status = Status.created;
    m_tick = 0;
    m_timer = createTimer(toDelegate(&tick));
}

~this()
{
    //
}

/** Returns the actual price as string */
@property string actualPrice() { return format("$%.2f", m_actualPrice); }

/** Returns true if the auction is open */
@property bool open() { return m_status == Status.open; }

/** Returns true if the auction is closed (i.e. not open) */
@property bool closed() { return !open; }

/** Returns the number of connected bidders */
@property int biddersCount() { return cast(int) m_bidders.length; }

/** Returns the auction parameters */
@property Params params() { return m_params; }

/** Sets the auction parameters */
@property void params(Params params) { m_params = params; }

/** Handles websocket connections to bid in this auction.

    Params:
        socket  = peer websocket
*/
void connect(scope WebSocket socket)
{
    if(closed || m_params.maxBidders <= biddersCount) {
        socket.send(message(Protocol.late));
        return;
    }

    auto sockid = cast(void*)socket;

    auto sendtask = runTask({
        while(socket.connected) {
            auto op = receiveOnly!Protocol();
            socket.send(message(op));
        }
    });

    string token = socket.receiveText();
    logInfo("> Bidder connection: %s", token);
    auto bidder = Bidder(sendtask, token);

    m_bidders[sockid] = bidder;
    scope (exit) m_bidders.remove(sockid);

    bidder.send(Protocol.tick);

    while (socket.waitForData()) {
        if(Protocol.ack == socket.receiveText()) {
            outcome(Protocol.win, sockid);
        }
    }

    logInfo("disconnect");
}

/** Starts this auction. */
void start()
{
    m_tick = 0;
    m_actualPrice = m_params.startPrice;
    m_timer.rearm(m_params.frequency, true);
    m_status = Status.open;

    logInfo("Auction started (%s)", Clock.currTime());
}

private:

    const enum Status : string { created = "new", open = "open", closed = "closed" };
    const enum Protocol : string { ack = "ack", tick = "tick", late = "late",
                                   win = "win", reserve = "res" };

    struct Bidder
    {
        Task task;
        string token;
        void send(Protocol op)
        {
            task.send(op);
        }
    };

    Params m_params;
    float m_actualPrice;
    int m_tick;
    Status m_status;
    Timer m_timer;
    Bidder[void*] m_bidders;

    /** Builds a JSON object with the auction state */
    string message(Protocol op)
    {
        Json j = Json.emptyObject;
        j.status = m_status;
        j.op = op;
        j.price = actualPrice;
        j.bidders = biddersCount;
        j.item = m_params.item;
        j.description = m_params.description;
        auto msg = j.toString();

        logDebug("=> %s", msg);

        return msg;
    }

    /** Handles the auction clock */
    void tick()
    {
        m_tick++;
        m_actualPrice -= m_params.delta;

        if(m_actualPrice <= m_params.reservePrice) {
            outcome(Protocol.reserve);

            logInfo("-Reserve price-");
        }

        broadcast();

        logInfo("[%s] Tick=%s, Bidders=%s, Price=%s",
                m_status, m_tick, biddersCount, actualPrice);
    }

    /** Broadcasts the auction state to all connected peers */
    void broadcast()
    {
        foreach(bidder; m_bidders) {
            bidder.send(Protocol.tick);
        }
    }

    /** Closes the auction for a winner, or by reached reserve */
    void outcome(Protocol op, void* tid = null)
    {
        if(open) {
            m_status = Status.closed;
            auto finalPrice = actualPrice;
            logInfo("Final Price: %s", finalPrice);
            m_timer.stop();

            if(tid !is null) {
                auto bidder = m_bidders[tid];
                logInfo("Winner: %s", bidder.token);
                bidder.send(op);
                m_bidders.remove(tid);
            }

            broadcast();
        }
    }

unittest
{
    Auction auction = new Auction;
    assert(auction.m_status == Status.created);
}

}
