extends RefCounted
## UPnP: ask the home router to forward a UDP port to this machine and report the
## public IP, so invite codes work across the internet without manual port forwarding.
## open_port() blocks for up to ~2 s; call it from a Thread (see open_port_async).

const LEASE_SECONDS := 4 * 3600
const DESCRIPTION := "Crater Bowl"

static func open_port(port: int) -> Dictionary:
	var u := UPNP.new()
	var err := u.discover(2000, 2, "InternetGatewayDevice")
	if err != UPNP.UPNP_RESULT_SUCCESS:
		return {"ok": false, "error": "No UPnP router found"}
	var gw := u.get_gateway()
	if gw == null or not gw.is_valid_gateway():
		return {"ok": false, "error": "Router doesn't support UPnP port mapping"}
	var r := u.add_port_mapping(port, port, DESCRIPTION, "UDP", LEASE_SECONDS)
	if r != UPNP.UPNP_RESULT_SUCCESS:
		return {"ok": false, "error": "Router refused the port mapping (code %d)" % r}
	var ip := u.query_external_address()
	if not is_public_ipv4(ip):
		# Double NAT / CGNAT: the router's "external" address is itself private.
		return {"ok": false, "error": "Your connection is behind carrier NAT (%s); friends outside your network can't reach you directly" % ip}
	return {"ok": true, "ip": ip, "port": port}

static func close_port(port: int) -> void:
	var u := UPNP.new()
	if u.discover(1000, 2, "InternetGatewayDevice") == UPNP.UPNP_RESULT_SUCCESS:
		u.delete_port_mapping(port, "UDP")

## Run open_port on a thread; cb(result: Dictionary) is called on the main thread.
static func open_port_async(port: int, cb: Callable) -> Thread:
	var t := Thread.new()
	t.start(func():
		var res := open_port(port)
		cb.call_deferred(res)
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
