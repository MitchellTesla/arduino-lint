// Code generated by "stringer -type=Type -linecomment"; DO NOT EDIT.

package projecttype

import "strconv"

func _() {
	// An "invalid array index" compiler error signifies that the constant values have changed.
	// Re-run the stringer command to generate them again.
	var x [1]struct{}
	_ = x[Sketch-0]
	_ = x[Library-1]
	_ = x[Platform-2]
	_ = x[PackageIndex-3]
	_ = x[All-4]
	_ = x[Not-5]
}

const _Type_name = "sketchlibraryplatformpackage-indexallN/A"

var _Type_index = [...]uint8{0, 6, 13, 21, 34, 37, 40}

func (i Type) String() string {
	if i < 0 || i >= Type(len(_Type_index)-1) {
		return "Type(" + strconv.FormatInt(int64(i), 10) + ")"
	}
	return _Type_name[_Type_index[i]:_Type_index[i+1]]
}
