import std/tables
import ../src/blastd

var n = initNet(PeerInfo(id: 1), 123)
let kind = n.register(7, initialFull = true)
kind.row.add Datum(key: 3, revision: 1, bytes: @[42'u8])
var incoming = @[
  Event(event: joined, source: PeerInfo(id: 2)),
  Event(event: data, source: PeerInfo(id: 3), kind: 7, datum: Datum(key: 4)),
  Event(event: data, source: PeerInfo(id: 2), kind: 7, datum: Datum(key: 5))]
var sent: seq[Datum]
gather = proc(): seq[Event] =
  result = incoming
  incoming = @[]
sendPeers = proc(p: Peer, peers: seq[PeerInfo]) = discard
sendDatum = proc(p: Peer, k: Kind, d: Datum) = sent.add d
traffic = proc(p: Peer) = discard
accept = proc(p: Peer, k: Kind, d: Datum): bool = true

n.tick(Seconds(0.025))
doAssert n.all.len == 1 and n.all[0].info.id == 2
doAssert kind.queue.len == 1 and kind.queue[0].datum.key == 5
doAssert sent.len >= 1 and sent[0].key == 3
doAssert abs(float64(sent[0].age) - 0.025) < 0.000001
incoming = @[Event(event: left, source: PeerInfo(id: 2))]
n.tick()
doAssert n.all.len == 0 and 2'u64 in n.peers

echo "blastd core checks passed"
