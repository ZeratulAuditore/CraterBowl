extends "res://tests/test_case.gd"
## UPnP mapping lifetime (#57): a mapping the game opens is removed when hosting ends
## (back to the menu, which covers leave match and match end) and on quit, exactly once.
## Every test injects a fake UPnP object, so no test ever talks to a real router.

const PortMapper := preload("res://src/net/port_mapper.gd")

class FakeGateway extends RefCounted:
	func is_valid_gateway() -> bool:
		return true

## Records calls the way a router would see them. One instance is shared across every
## UPNP object the factory hands out, like one physical router.
class FakeRouter extends RefCounted:
	var mapped := {}             # port -> true while the router holds the forward
	var adds := 0
	var deletes := 0
	var delete_result := 0       # UPNP.UPNP_RESULT_SUCCESS
	var discover_result := 0
	var ip := "73.12.1.200"

class FakeUPNP extends RefCounted:
	var router: FakeRouter
	func _init(r: FakeRouter) -> void:
		router = r
	func discover(_timeout := 2000, _ttl := 2, _device := "") -> int:
		return router.discover_result
	func get_gateway():
		return FakeGateway.new()
	func add_port_mapping(port: int, _port_internal := 0, _desc := "", _proto := "UDP", _duration := 0) -> int:
		router.adds += 1
		router.mapped[port] = true
		return 0
	func delete_port_mapping(port: int, _proto := "UDP") -> int:
		router.deletes += 1
		if router.delete_result == 0:
			router.mapped.erase(port)
		return router.delete_result
	func query_external_address() -> String:
		return router.ip

func _fake() -> FakeRouter:
	var r := FakeRouter.new()
	PortMapper.release_all()          # leftovers from another test
	PortMapper.upnp_factory = func(): return FakeUPNP.new(r)
	return r

func _restore() -> void:
	PortMapper.wait_pending()
	PortMapper.release_all()
	PortMapper.upnp_factory = PortMapper.default_upnp

func test_map_then_release_unmaps() -> void:
	var r := _fake()
	var res := PortMapper.open_port(24565)
	assert_true(res.get("ok", false), "fake mapping succeeds")
	assert_eq(r.mapped.keys(), [24565], "router holds the forward")
	assert_eq(PortMapper.mapped_ports(), [24565], "mapper remembers what it opened")
	PortMapper.release_all()
	assert_eq(r.mapped.size(), 0, "forward removed when hosting ends")
	assert_eq(PortMapper.mapped_ports(), [], "nothing left to release")
	_restore()

func test_double_release_is_idempotent() -> void:
	var r := _fake()
	PortMapper.open_port(24565)
	PortMapper.open_port(24566)
	PortMapper.release_all()
	PortMapper.release_all()
	PortMapper.release_all_async()
	PortMapper.wait_pending()
	assert_eq(r.deletes, 2, "each mapping deleted exactly once")
	_restore()

func test_release_without_mapping_touches_nothing() -> void:
	var r := _fake()
	PortMapper.release_all()
	PortMapper.release_all_async()
	PortMapper.wait_pending()
	assert_eq([r.adds, r.deletes], [0, 0], "no router traffic when nothing was mapped")
	_restore()

func test_async_release_off_main_thread() -> void:
	var r := _fake()
	PortMapper.open_port(24565)
	PortMapper.release_all_async()
	assert_eq(PortMapper.mapped_ports(), [], "forgotten immediately on the main thread")
	PortMapper.wait_pending()
	assert_eq(r.mapped.size(), 0, "worker removed the forward")
	_restore()

func test_reopen_during_pending_release_keeps_new_mapping() -> void:
	var r := _fake()
	PortMapper.open_port(24565)
	PortMapper.release_all_async()
	PortMapper.open_port(24565)        # player hosts again before the worker ran
	PortMapper.wait_pending()
	assert_eq(r.mapped.keys(), [24565], "the new host's forward survives the old release")
	assert_eq(PortMapper.mapped_ports(), [24565], "and is still tracked for the next release")
	_restore()

func test_failed_delete_is_harmless() -> void:
	var r := _fake()
	PortMapper.open_port(24565)
	r.delete_result = 1                # router refuses (or vanished)
	PortMapper.release_all()
	assert_eq(PortMapper.mapped_ports(), [], "forgotten anyway; the 4 h lease is the fallback")
	PortMapper.release_all()
	assert_eq(r.deletes, 1, "not retried")
	_restore()

func test_cgnat_mapping_tracked_no_router_not() -> void:
	var r := _fake()
	r.ip = "100.64.0.9"                # carrier NAT: mapping added but unusable
	var res := PortMapper.open_port(24565)
	assert_true(not res.get("ok", false), "CGNAT counts as failure")
	assert_eq(PortMapper.mapped_ports(), [24565], "the router still holds it, so it is still released")
	PortMapper.release_all()
	assert_eq(r.mapped.size(), 0, "released")
	r.discover_result = 1
	PortMapper.open_port(24566)
	assert_eq(PortMapper.mapped_ports(), [], "no router, nothing tracked")
	_restore()

func test_quit_guard_releases_on_close_request_and_exit() -> void:
	var r := _fake()
	PortMapper.open_port(24565)
	var g := PortMapper.make_quit_guard()
	g._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_eq(r.mapped.size(), 0, "window close removes the forward")
	PortMapper.open_port(24566)
	g._notification(Node.NOTIFICATION_EXIT_TREE)   # get_tree().quit() tears the tree down
	assert_eq(r.mapped.size(), 0, "quit removes the forward")
	g._notification(Node.NOTIFICATION_EXIT_TREE)
	assert_eq(r.deletes, 2, "a second quit notification deletes nothing")
	g.free()
	_restore()
