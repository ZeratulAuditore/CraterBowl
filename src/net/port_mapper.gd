extends RefCounted
## UPnP: ask the home router to forward a UDP port to this machine and report the
## public IP, so invite codes work across the internet without manual port forwarding.
## open_port() blocks for up to ~2 s; call it from a Thread (see open_port_async).
##
## Every mapping the router accepts is remembered (with the UPNP object that found the
## gateway, so removing it needs no second discovery) and removed when hosting ends (#57):
## Launch.go_to_menu calls release_all_async() (leave match, match end, back to menu), and a
## small quit guard node under /root calls release_all() on window close or tree exit.
## Releasing is idempotent and best effort: a refused delete is forgotten, and the 4 h lease
## remains the fallback (crash, router gone).

const LEASE_SECONDS := 4 * 3600
const DESCRIPTION := "Crater Bowl"

## Returns a UPNP-like object. Tests swap in a fake so they never reach a real router.
static var upnp_factory: Callable = default_upnp
static var _lock := Mutex.new()
static var _mapped := {}        # port -> UPNP object that mapped it (guarded by _lock)
static var _tasks: Array[int] = []   # WorkerThreadPool ids of pending async releases
static var _guard: Node

static func default_upnp():
	return UPNP.new()

static func open_port(port: int) -> Dictionary:
	_lock.lock()
	var res := _open_locked(port)
	_lock.unlock()
	return res

static func _open_locked(port: int) -> Dictionary:
	var u = upnp_factory.call()
	var err: int = u.discover(2000, 2, "InternetGatewayDevice")
	if err != UPNP.UPNP_RESULT_SUCCESS:
		return {"ok": false, "error": "No UPnP router found"}
	var gw = u.get_gateway()
	if gw == null or not gw.is_valid_gateway():
		return {"ok": false, "error": "Router doesn't support UPnP port mapping"}
	var r: int = u.add_port_mapping(port, port, DESCRIPTION, "UDP", LEASE_SECONDS)
	if r != UPNP.UPNP_RESULT_SUCCESS:
		return {"ok": false, "error": "Router refused the port mapping (code %d)" % r}
	_mapped[port] = u            # the router holds it now, whatever happens next
	var ip: String = u.query_external_address()
	if not is_public_ipv4(ip):
		# Double NAT / CGNAT: the router's "external" address is itself private.
		return {"ok": false, "error": "Your connection is behind carrier NAT (%s); friends outside your network can't reach you directly" % ip}
	return {"ok": true, "ip": ip, "port": port}

## Ports this session mapped and hasn't released yet.
static func mapped_ports() -> Array:
	_lock.lock()
	var p := _mapped.keys()
	_lock.unlock()
	p.sort()
	return p

static func close_port(port: int) -> void:
	_lock.lock()
	var u = _mapped.get(port)
	_mapped.erase(port)
	_lock.unlock()
	_delete(port, u)

## Remove every mapping now, on this thread (quit path; one request per port, no discovery).
static func release_all() -> void:
	for port in _take_all():
		_delete(port[0], port[1])

## Hosting ended: forget the mappings now and remove them on a worker thread.
static func release_all_async() -> void:
	_reap(false)
	var pending := _take_all()
	if pending.is_empty():
		return
	_tasks.append(WorkerThreadPool.add_task(func():
		for pu in pending:
			_lock.lock()
			# A newer open_port re-mapped this port after we forgot it: that one is live, keep it.
			if not _mapped.has(pu[0]):
				pu[1].delete_port_mapping(pu[0], "UDP")
			_lock.unlock(), false, "upnp release"))

## Block until async releases finish (quit, tests).
static func wait_pending() -> void:
	_reap(true)

static func _reap(block: bool) -> void:
	for id in _tasks.duplicate():
		if block or WorkerThreadPool.is_task_completed(id):
			WorkerThreadPool.wait_for_task_completion(id)
			_tasks.erase(id)

static func _take_all() -> Array:
	_lock.lock()
	var out := []
	for port in _mapped:
		out.append([port, _mapped[port]])
	_mapped.clear()
	_lock.unlock()
	return out

static func _delete(port: int, u) -> void:
	_lock.lock()
	if u == null:
		u = upnp_factory.call()
		if u.discover(1000, 2, "InternetGatewayDevice") != UPNP.UPNP_RESULT_SUCCESS:
			u = null
	if u != null:
		u.delete_port_mapping(port, "UDP")
	_lock.unlock()

## Node that releases every mapping when the app closes. Lives under /root so it
## survives scene changes; installed on the first successful open_port_async.
class QuitGuard extends Node:
	var on_quit: Callable
	func _notification(what: int) -> void:
		if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
			on_quit.call()

static func make_quit_guard() -> Node:
	var g := QuitGuard.new()
	g.name = "UpnpQuitGuard"
	g.on_quit = func():
		wait_pending()
		release_all()
	return g

static func _install_quit_guard() -> void:
	if is_instance_valid(_guard):
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	_guard = make_quit_guard()
	tree.root.add_child(_guard)

## Run open_port on a thread; cb(result: Dictionary) is called on the main thread.
static func open_port_async(port: int, cb: Callable) -> Thread:
	var t := Thread.new()
	t.start(func():
		var res := open_port(port)
		(func():
			_install_quit_guard()
			cb.call(res)).call_deferred()
		return res)
	return t

static func is_public_ipv4(ip: String) -> bool:
	var p := ip.split(".")
	if p.size() != 4:
		return false
	for x in p:
		if not x.is_valid_int() or int(x) < 0 or int(x) > 255:
			return false
	var a := int(p[0])
	var b := int(p[1])
	if a == 10 or a == 127 or a == 0 or a >= 224:
		return false
	if a == 172 and b >= 16 and b <= 31:
		return false
	if a == 192 and b == 168:
		return false
	if a == 100 and b >= 64 and b <= 127:   # carrier-grade NAT
		return false
	if a == 169 and b == 254:
		return false
	return true
