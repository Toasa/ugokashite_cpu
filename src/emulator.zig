const std = @import("std");
const CPU = @import("cpu.zig").CPU;
const InstBytes = @import("cpu.zig").InstBytes;
usingnamespace @import("const.zig");

// sum from 0 to 10.
const program = [_]u16 {
    0b0100100000000000,
    0b0100000000000000,
    0b0100100100000000,
    0b0100000100000001,
    0b0100101000000000,
    0b0100001000000000,
    0b0100101100000000,
    0b0100001100001010,
    0b0000101000100000,
    0b0000100001000000,
    0b0111000001000000,
    0b0101001001100000,
    0b0101100000001110,
    0b0110000000001000,
    0b0111100000000000,
};

pub const Emulator = struct {
    const Self = @This();
    cpu: CPU,

    pub fn init() Self {
        var rom = [_]u16{0} ** MEM_SIZE;
        for (program) |data, i| {
            rom[i] = data;
        }
        const cpu = CPU.init(rom);
        return Self {
            .cpu = cpu,
        };
    }

    pub fn run(self: *Self) void {
        var status_code = CPU.ExecuteStatusCode.NonHalt;
        
        while (status_code == .NonHalt) {
            const inst_bytes = self.cpu.fetch();
            const inst = self.cpu.decode(inst_bytes);
            status_code = self.cpu.execute(inst);
            // inst.print();
        }
    }
};

test "emulator" {
    var emulator = Emulator.init();
    emulator.run();

    std.testing.expect(emulator.cpu.regs[0] == 55);
}