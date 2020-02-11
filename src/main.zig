const std = @import("std");
const Emulator = @import("emulator.zig").Emulator;

pub fn main() anyerror!void {
    var emu = Emulator.init();
    emu.run();
}
