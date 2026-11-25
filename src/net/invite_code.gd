extends RefCounted
## IPv4 + port <-> 10-char Crockford base32 code "XXXXX-XXXXX". Pure.

const ALPHABET := "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

static func encode(ip: String, port: int) -> String:
	var parts := ip.split(".")
	if parts.size() != 4 or port < 1 or port > 65535:
		return ""
	var v := 0
	for p in parts:
		if not p.is_valid_int() or int(p) < 0 or int(p) > 255:
			return ""
		v = (v << 8) | int(p)
	v = (v << 16) | port
	var out := ""
	for i in 10:
		out = ALPHABET[v & 31] + out
		v >>= 5
	return out.substr(0, 5) + "-" + out.substr(5)

## Returns {"ip": String, "port": int} or {} if invalid.
static func decode(code: String) -> Dictionary:
	var c := code.strip_edges().to_upper().replace("-", "").replace(" ", "")
	c = c.replace("O", "0").replace("I", "1").replace("L", "1")
	if c.length() != 10:
		return {}
	var v := 0
	for ch in c:
		var d := ALPHABET.find(ch)
		if d < 0:
			return {}
		v = (v << 5) | d
	if v >> 48 != 0:
		return {}
	var port := v & 0xFFFF
	var ipv := v >> 16
	if port == 0:
		return {}
	return {"ip": "%d.%d.%d.%d" % [(ipv >> 24) & 255, (ipv >> 16) & 255, (ipv >> 8) & 255, ipv & 255], "port": port}

static func looks_like_code(s: String) -> bool:
	return not decode(s).is_empty() and s.find(".") < 0
