## Test map: registration; peer lifecycle/hints; event gating; sampling/pruning; policy hooks.
import std/[math, sequtils, sets, tables, unittest]
import ../src/blastd

type
  PeerNotice = object
    dst  : PeerId
    peers: seq[PeerInfo]
  Datagram = object
    dst  : PeerId
    kind : KindId
    datum: Datum

var
  incoming       : seq[Event]
  peerNotices    : seq[PeerNotice]
  datagrams      : seq[Datagram]
  connected      : seq[PeerId]
  disconnected   : seq[PeerId]
  trafficked     : seq[PeerId]
  accepted       : seq[(PeerId, KindId, Datum)]
  acceptIncoming : bool = true

proc bindHooks() =
  incoming.setLen(0)
  peerNotices.setLen(0)
  datagrams.setLen(0)
  connected.setLen(0)
  disconnected.setLen(0)
  trafficked.setLen(0)
  accepted.setLen(0)
  acceptIncoming = true

  gather = proc(): seq[Event] =
    result = incoming
    incoming.setLen(0)
  connect = proc(info: PeerInfo) = connected.add info.id
  disconnect = proc(id: PeerId) = disconnected.add id
  sendPeers = proc(p: Peer, peers: seq[PeerInfo]) =
    peerNotices.add PeerNotice(dst: p.info.id, peers: peers)
  sendDatum = proc(p: Peer, k: Kind, d: Datum) =
    datagrams.add Datagram(dst: p.info.id, kind: k.id, datum: d)
  accept = proc(p: Peer, k: Kind, d: Datum): bool =
    accepted.add (p.info.id, k.id, d)
    acceptIncoming
  traffic = proc(p: Peer) = trafficked.add p.info.id
  pairChance = nil
  retention = nil
  placeFar = nil
  desyncCost = nil

proc info(id: PeerId, endpoint = ""): PeerInfo =
  PeerInfo(id: id, playerId: "player-" & $id, endpoint: endpoint)

proc connectedPeer(n: var Net, id: PeerId,
                   far = false): Peer =
  result = Peer(info: info(id), ping: NoPing, up: (0'f32, 1'f32))
  n.peers[id] = result
  n.all.add result
  if far: n.far.add result
  else: n.near.add result

proc hasPeer(infos: openArray[PeerInfo], id: PeerId): bool =
  for p in infos:
    if p.id == id: return true

suite "blastd network core":
  setup:
    bindHooks()

  test "initialization establishes self and default ping limit":
    let n = initNet(info(1), 17)
    check n.selph.id == 1
    check n.pingLimit == 2000'u64
    check n.peers.len == 0
    check n.all.len == 0

  test "initialization rejects a zero self id":
    expect AssertionDefect:
      discard initNet(PeerInfo(), 17)

  test "registration preserves all kind options":
    var n = initNet(info(1), 17)
    let k = n.register(8, dropOld = true, once = true, initialFull = true)
    check k.id == 8
    check k.dropOld
    check k.once
    check k.initialFull
    check n.kinds[8] == k

  test "registration rejects a duplicate kind id":
    var n = initNet(info(1), 17)
    discard n.register(8)
    expect AssertionDefect:
      discard n.register(8)

  # Discovery hints do not imply active membership.
  test "seeding learns descriptors without connecting them":
    var n = initNet(info(1), 17)
    n.seed([info(0), info(1), info(2, "seeded")])
    check n.peers.len == 1
    check n.peers[2].info.endpoint == "seeded"
    check n.all.len == 0
    check connected.len == 0

  test "joining sends known peers and initial full state":
    var n = initNet(info(1), 17)
    discard n.connectedPeer(3)
    let k = n.register(7, initialFull = true)
    let d = Datum(key: 11, revision: 4, bytes: @[1'u8, 2, 3])
    k.row.add d
    incoming = @[Event(event: joined, source: info(2, "joined"))]
    traffic = proc(p: Peer) = p.up.coefficient = 0

    n.tick()

    check n.all.len == 2
    check n.near.len == 2
    check n.far.len == 0
    check n.peers[2].info.endpoint == "joined"
    check peerNotices.len == 2
    check peerNotices[0].dst == 3
    check peerNotices[0].peers.len == 1
    check peerNotices[0].peers[0].id == 2
    check peerNotices[1].dst == 2
    check peerNotices[1].peers.hasPeer(1)
    check peerNotices[1].peers.hasPeer(3)
    check not peerNotices[1].peers.hasPeer(2)
    check datagrams.len == 1
    check datagrams[0].dst == 2
    check datagrams[0].kind == 7
    check datagrams[0].datum.key == d.key
    check datagrams[0].datum.revision == d.revision
    check datagrams[0].datum.bytes == d.bytes

  test "joining chooses far placement through policy hook":
    var n = initNet(info(1), 17)
    placeFar = proc(p: Peer): bool = true
    incoming = @[Event(event: joined, source: info(2))]
    n.tick()
    check n.all.len == 1
    check n.near.len == 0
    check n.far.len == 1

  test "duplicate join leaves membership and sends bootstrap once":
    var n = initNet(info(1), 17)
    incoming = @[
      Event(event: joined, source: info(2)),
      Event(event: joined, source: info(2, "new endpoint"))]
    n.tick()
    check n.all.len == 1
    check peerNotices.len == 1

  test "join skips initial rows when kind is not initial full":
    var n = initNet(info(1), 17)
    let k = n.register(7)
    k.row.add Datum(key: 3)
    traffic = proc(p: Peer) = p.up.coefficient = 0
    incoming = @[Event(event: joined, source: info(2))]
    n.tick()
    check datagrams.len == 0

  test "leave removes peer from membership and retains descriptor":
    var n = initNet(info(1), 17)
    incoming = @[
      Event(event: joined, source: info(2, "remember me")),
      Event(event: left, source: info(2))]
    n.tick()
    check n.all.len == 0
    check n.near.len == 0
    check n.far.len == 0
    check 2'u64 in n.peers
    check n.peers[2].info.endpoint == "remember me"

  test "rejoin refreshes peer descriptor":
    var n = initNet(info(1), 17)
    incoming = @[
      Event(event: joined, source: info(2, "old")),
      Event(event: left, source: info(2)),
      Event(event: joined, source: info(2, "fresh"))]
    n.tick()
    check n.all.len == 1
    check n.peers[2].info.endpoint == "fresh"

  test "joining ignores zero and self descriptors":
    var n = initNet(info(1), 17)
    incoming = @[
      Event(event: joined, source: info(0)),
      Event(event: joined, source: info(1))]
    n.tick()
    check n.peers.len == 0
    check n.all.len == 0

  # Inbound lifecycle and payload gates.
  test "peer table learns hints and records their informant":
    var n = initNet(info(1), 17)
    let source = n.connectedPeer(2)
    discard n.connectedPeer(3)
    incoming = @[Event(event: peerTable, source: source.info,
                       peers: @[info(0), info(1), info(2), info(4)])]
    n.tick()
    check 4'u64 in n.peers
    check n.all.len == 2
    check 2'u64 in n.peers[4].informants
    check peerNotices.len == 1
    check peerNotices[0].dst == 3
    check peerNotices[0].peers.len == 1
    check peerNotices[0].peers[0].id == 4

  test "peer table from disconnected source is ignored":
    var n = initNet(info(1), 17)
    n.seed([info(2)])
    incoming = @[Event(event: peerTable, source: info(2), peers: @[info(3)])]
    n.tick()
    check 3'u64 notin n.peers
    check n.peers[2].informants.len == 0

  test "zero and self sourced events are ignored":
    var n = initNet(info(1), 17)
    incoming = @[
      Event(event: joined, source: info(0)),
      Event(event: joined, source: info(1)),
      Event(event: peerTable, source: info(0), peers: @[info(4)])]
    n.tick()
    check n.peers.len == 0
    check n.all.len == 0

  test "accepted known data is queued with its source":
    var n = initNet(info(1), 17)
    let k = n.register(7)
    let d = Datum(key: 14, revision: 2, bytes: @[9'u8, 8])
    incoming = @[
      Event(event: joined, source: info(2)),
      Event(event: data, source: info(2), kind: 7, datum: d)]
    n.tick()
    check accepted.len == 1
    check accepted[0][0] == 2
    check accepted[0][1] == 7
    check accepted[0][2].key == d.key
    check accepted[0][2].revision == d.revision
    check accepted[0][2].bytes == d.bytes
    check k.queue.len == 1
    check k.queue[0].source == 2
    check k.queue[0].datum.key == d.key
    check k.queue[0].datum.revision == d.revision
    check k.queue[0].datum.bytes == d.bytes

  test "rejected data is not queued":
    var n = initNet(info(1), 17)
    let k = n.register(7)
    acceptIncoming = false
    incoming = @[
      Event(event: joined, source: info(2)),
      Event(event: data, source: info(2), kind: 7, datum: Datum(key: 5))]
    n.tick()
    check accepted.len == 1
    check k.queue.len == 0

  test "unknown kind does not call accept or queue data":
    var n = initNet(info(1), 17)
    incoming = @[
      Event(event: joined, source: info(2)),
      Event(event: data, source: info(2), kind: 99)]
    n.tick()
    check accepted.len == 0
    check n.kinds.len == 0

  test "data from an unconnected peer is ignored":
    var n = initNet(info(1), 17)
    let k = n.register(7)
    n.seed([info(2)])
    incoming = @[Event(event: data, source: info(2), kind: 7)]
    n.tick()
    check accepted.len == 0
    check k.queue.len == 0

  # Row aging, stochastic sampling and peer-retention policies.
  test "outgoing row age advances before transmission":
    var n = initNet(info(1), 17)
    let k = n.register(7)
    k.row.add Datum(key: 3, revision: 1)
    let p = n.connectedPeer(2)
    n.tick(25)
    check datagrams.len == 1
    check datagrams[0].dst == 2
    check datagrams[0].datum.age == 25
    p.up.coefficient = 0
    n.tick(75)
    check k.row[0].age == 100
    check datagrams.len == 1

  test "coefficient one sends every row to each peer":
    var n = initNet(info(1), 17)
    let k = n.register(7)
    k.row = @[Datum(key: 1), Datum(key: 2), Datum(key: 3)]
    discard n.connectedPeer(2)
    discard n.connectedPeer(3, far = true)
    n.tick()
    check datagrams.len == 6
    check datagrams.countIt(it.dst == 2) == 3
    check datagrams.countIt(it.dst == 3) == 3

  test "zero sample coefficient sends no rows":
    var n = initNet(info(1), 17)
    let k = n.register(7)
    k.row.add Datum(key: 1)
    let p = n.connectedPeer(2)
    p.up.coefficient = 0
    n.tick()
    check datagrams.len == 0

  test "far peer transmission rate squares the coefficient":
    var n = initNet(info(1), 712)
    let k = n.register(7)
    k.row.add Datum(key: 1)
    let near = n.connectedPeer(2)
    let far = n.connectedPeer(3, far = true)
    near.up.coefficient = 0.5
    far.up.coefficient = 0.5

    for i in 0..<10000: n.tick()

    let nearRate = float64(datagrams.countIt(it.dst == 2)) / 10000
    let farRate = float64(datagrams.countIt(it.dst == 3)) / 10000
    check abs(nearRate - 0.5) < 0.08
    check abs(farRate - 0.25) < 0.08

  test "traffic policy runs once for each connected peer":
    var n = initNet(info(1), 17)
    discard n.connectedPeer(2)
    discard n.connectedPeer(3, far = true)
    n.tick()
    check trafficked.toHashSet == [2'u64, 3'u64].toHashSet

  test "peer above ping limit is eventually pruned by sampling":
    var n = initNet(info(1), 17)
    let slow = n.connectedPeer(2)
    slow.ping = 2001
    var ticks = 0
    while n.all.len > 0 and ticks < 20000:
      n.tick()
      inc ticks
    check disconnected == @[2'u64]
    check n.all.len == 0
    check n.near.len == 0
    check n.far.len == 0
    check 2'u64 in n.peers

  test "peer exactly at ping limit remains connected":
    var n = initNet(info(1), 17)
    let edge = n.connectedPeer(2)
    edge.ping = 2000
    n.tick()
    check disconnected.len == 0
    check n.all.len == 1

  test "unknown ping remains connected":
    var n = initNet(info(1), 17)
    discard n.connectedPeer(2)
    n.tick()
    check disconnected.len == 0
    check n.all.len == 1

  test "retention samples peers once before moving them to far set":
    var n = initNet(info(1), 17)
    var sampled: seq[PeerId]
    for id in 2'u64..5'u64:
      let p = n.connectedPeer(id)
      p.up.load = 5 # Push per-peer retention sampling probability above one.
    retention = proc(p: Peer): float32 =
      sampled.add p.info.id
      0
    n.tick()
    check sampled == @[2'u64, 3, 4, 5]
    check n.near.len == 0
    check n.far.len == 4
    check n.all.len == 4
    check n.all.allIt(it in n.far)

  test "full retention keeps peers in their current set":
    var n = initNet(info(1), 17)
    discard n.connectedPeer(2)
    retention = proc(p: Peer): float32 = 1
    n.tick()
    check n.near.len == 1
    check n.far.len == 0

  test "pair policy connects idle known peers only":
    var n = initNet(info(1), 17)
    n.seed([info(2), info(3)])
    incoming = @[Event(event: joined, source: info(2))]
    pairChance = proc(p: Peer): float32 = 1
    n.tick()
    check connected == @[3'u64]
    check n.all.len == 1

  test "zero pair chance makes no connection attempts":
    var n = initNet(info(1), 17)
    n.seed([info(2)])
    pairChance = proc(p: Peer): float32 = 0
    n.tick()
    check connected.len == 0

  # Host policy hooks and provenance view.
  test "desync policy receives peer and severity":
    var n = initNet(info(1), 17)
    let p = n.connectedPeer(2)
    var reports: seq[(PeerId, float32)]
    n.recordDesync = proc(p: Peer, severity: float32) =
      reports.add (p.info.id, severity)
    desyncCost = proc(severity: float32): float32 = 10
    n.reportDesync(2, 0.75)
    n.reportDesync(99, 1)
    check reports == @[(2'u64, 0.75'f32)]
    check p.trust == 0

  test "fallback desync cost is clamped to nonnegative trust loss":
    var n = initNet(info(1), 17)
    let p = n.connectedPeer(2)
    p.trust = 0.8
    desyncCost = proc(severity: float32): float32 = severity * 0.5
    n.reportDesync(2, 0.4)
    check abs(p.trust - 0.6) < 0.00001
    desyncCost = proc(severity: float32): float32 = -10
    n.reportDesync(2, 1)
    check abs(p.trust - 0.6) < 0.00001

  test "desync rejects negative and non-finite severity":
    var n = initNet(info(1), 17)
    discard n.connectedPeer(2)
    expect AssertionDefect:
      n.reportDesync(2, -0.1)
    expect AssertionDefect:
      n.reportDesync(2, Inf.float32)
    expect AssertionDefect:
      n.reportDesync(2, NaN.float32)

  test "informant edges map source to learned peer":
    var n = initNet(info(1), 17)
    let p = n.connectedPeer(2)
    p.informants.incl 3
    p.informants.incl 4
    var edges: seq[Edge]
    for edge in n.informantEdges: edges.add edge
    check edges.len == 2
    check (3'u64, 2'u64) in edges
    check (4'u64, 2'u64) in edges
