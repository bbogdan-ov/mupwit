//
// Unlike `main_hotreload`, this module just imports MUPWIT and directly calls
// needed functions.
//

package main_release

import "core:mem"

import mupwit ".."
import "../common"

main :: proc() {
	context.logger = common.make_logger()

	track := common.make_tracking_allocator(context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	defer common.tracking_allocator_report_and_destroy(&track)

	mupwit.init()
	for mupwit.should_run() {}
	mupwit.destroy()
}
