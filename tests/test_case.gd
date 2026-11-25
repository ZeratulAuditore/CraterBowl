extends RefCounted
## Base class for tests: collect failures instead of aborting.

var errors: Array[String] = []

func assert_true(cond: bool, msg: String = "expected true") -> void:
	if not cond:
		errors.append(msg)

func assert_eq(a, b, msg: String = "") -> void:
	if a != b:
		errors.append("%s expected %s == %s" % [msg, str(a), str(b)])

func assert_near(a: float, b: float, eps: float = 0.001, msg: String = "") -> void:
	if absf(a - b) > eps:
		errors.append("%s expected %f ~= %f" % [msg, a, b])
