usingnamespace @import("const.zig");
const std = @import("std");

pub const CPU = struct {
    const Self = @This();

    regs: [8]u16,
    flag: u1,
    pc: u8,

    // 8bit address space
    rom: [MEM_SIZE] u16,
    ram: [MEM_SIZE] u16,

    pub fn init(rom: [MEM_SIZE]u16) Self {
        return Self {
            .regs = [_]u16{0} ** 8,
            .flag = 0,
            .pc = 0,
            .rom = rom,
            .ram = [_]u16{0} ** MEM_SIZE,
        };
    }

    pub fn fetch(self: *Self) InstBytes {
        const data = self.readROM(self.pc);
        self.pc += 1;
        return InstBytes.init(data);
    }
    
    pub fn decode(self: Self, inst_bytes: InstBytes) InstSet {
        const code = inst_bytes.getInstCode();
        switch (code) {
            // mov
            0b0000 => {
                const reg1 = inst_bytes.getReg1Id();
                const reg2 = inst_bytes.getReg2Id();
                const mov = InstSet.MovInst.init(reg1, reg2);
                return InstSet{ .Mov = mov };
            },
            // add
            0b0001 => {
                const reg1 = inst_bytes.getReg1Id();
                const reg2 = inst_bytes.getReg2Id();
                const add = InstSet.AddInst.init(reg1, reg2);
                return InstSet{ .Add = add };
            },
            // sub
            0b0010 => {
                const reg1 = inst_bytes.getReg1Id();
                const reg2 = inst_bytes.getReg2Id();
                const sub = InstSet.SubInst.init(reg1, reg2);
                return InstSet{ .Sub = sub };
            },
            // and
            0b0011 => {
                const reg1 = inst_bytes.getReg1Id();
                const reg2 = inst_bytes.getReg2Id();
                const a = InstSet.AndInst.init(reg1, reg2);
                return InstSet{ .And = a };
            },
            // or
            0b0100 => {
                const reg1 = inst_bytes.getReg1Id();
                const reg2 = inst_bytes.getReg2Id();
                const o = InstSet.OrInst.init(reg1, reg2);
                return InstSet{ .Or = o };
            },
            // sl (shift left)
            0b0101 => {
                const reg1 = inst_bytes.getReg1Id();
                const sl = InstSet.SlInst.init(reg1);
                return InstSet{ .Sl = sl };
            },
            // sr (shift right)            
            0b0110 => {
                const reg1 = inst_bytes.getReg1Id();
                const sr = InstSet.SrInst.init(reg1);
                return InstSet{ .Sr = sr };
            },
            // sra (shift right arithmetic)
            0b0111 => {
                const reg1 = inst_bytes.getReg1Id();
                const sra = InstSet.SraInst.init(reg1);
                return InstSet{ .Sra = sra };
            },
            // load immediate value low
            0b1000 => {
                const reg1 = inst_bytes.getReg1Id();
                const data = inst_bytes.getData();
                const ldl = InstSet.LdlInst.init(reg1, data);
                return InstSet{ .Ldl = ldl };
            },
            // load immediate value high
            0b1001 => {
                const reg1 = inst_bytes.getReg1Id();
                const data = inst_bytes.getData();
                const ldh = InstSet.LdhInst.init(reg1, data);
                return InstSet{ .Ldh = ldh };
            },
            // cmp
            0b1010 => {
                const reg1 = inst_bytes.getReg1Id();
                const reg2 = inst_bytes.getReg2Id();
                const cmp = InstSet.CmpInst.init(reg1, reg2);
                return InstSet{ .Cmp = cmp };
            },
            // jmp if equal
            0b1011 => {
                const addr = inst_bytes.getData();
                const je = InstSet.JeInst.init(addr);
                return InstSet{ .Je = je };
            },
            // jmp
            0b1100 => {
                const addr = inst_bytes.getData();
                const jmp = InstSet.JmpInst.init(addr);
                return InstSet{ .Jmp = jmp };
            },
            // load            
            0b1101 => {
                const reg1 = inst_bytes.getReg1Id();
                const addr = inst_bytes.getData();
                const ld = InstSet.LdInst.init(reg1, addr);
                return InstSet{ .Ld = ld };
            },
            // store
            0b1110 => {
                const reg1 = inst_bytes.getReg1Id();
                const addr = inst_bytes.getData();
                const st = InstSet.StInst.init(reg1, addr);
                return InstSet{ .St = st };
            },
            // halt
            0b1111 => {
                const hlt = InstSet.HltInst.init();
                return InstSet{ .Hlt = hlt };
            },
        }
    }

    pub const ExecuteStatusCode = enum {
        NonHalt,
        Halt,
    };

    pub fn execute(self: *Self, inst: InstSet) ExecuteStatusCode {
        switch (inst) {
            .Mov => |mov| {
                self.regs[mov.reg1] = self.regs[mov.reg2];
            },
            .Add => |add| {
                self.regs[add.reg1] += self.regs[add.reg2];
            },
            .Sub => |sub| {
                self.regs[sub.reg1] -= self.regs[sub.reg2];
            },
            .And => |an| {
                self.regs[an.reg1] &= self.regs[an.reg2];
            },
            .Or => |o| {
                self.regs[o.reg1] |= self.regs[o.reg2];
            },
            .Sl => |sl| {
                self.regs[sl.reg1] <<= 1;
            },
            .Sr => |sr| {
                self.regs[sr.reg1] >>= 1;
            },
            .Sra => |sra| {
                // 0b1000_0000_0000_0000 or 0b0000_0000_0000_0000
                const msb_mask: u16 = self.regs[sra.reg1] & (0b1000000000000000);
                self.regs[sra.reg1] >>= 1;
                self.regs[sra.reg1] |= msb_mask;
            },
            .Ldl => |ldl| {
                self.regs[ldl.reg1] &= 0xFF00;
                self.regs[ldl.reg1] |= ldl.data;
            },
            .Ldh => |ldh| {
                self.regs[ldh.reg1] &= 0x00FF;
                var d: u16 = ldh.data;
                d <<= 8;
                self.regs[ldh.reg1] |= d;
            },
            .Cmp => |cmp| {
                if (self.regs[cmp.reg1] == self.regs[cmp.reg2]) {
                    self.flag = 1;
                } else {
                    self.flag = 0;
                }
            },
            .Je => |je| {
                if (self.flag == 1) {
                    self.pc = je.addr;
                }
            },
            .Jmp => |jmp| {
                self.pc = jmp.addr;
            },
            .Ld => |ld| {
                const addr = ld.addr;
                const data = self.readRAM(addr);
                self.regs[ld.reg1] = data;
            },
            .St => |st| {
                const addr = st.addr;
                const data = self.regs[st.reg1];
                self.writeRAM(addr, data);
            },
            .Hlt => {
                return ExecuteStatusCode.Halt;
            },
        }
        return ExecuteStatusCode.NonHalt;
    }

    fn readROM(self: Self, addr: u8) u16 {
        return self.rom[addr];
    }

    fn readRAM(self: Self, addr: u8) u16 {
        return self.ram[addr];
    }

    fn writeRAM(self: *Self, addr: u8, data: u16) void {
        self.ram[addr] = data;
    }

    pub fn printRegs(self: Self) void {
        for (self.regs) |reg, i| {
            std.debug.warn("    reg{}: {}\n", i, reg);
        }
    }
};

pub const InstBytes = struct {
    const Self = @This();
    data: u16,
    pub fn init(data: u16) Self {
        return Self {
            .data = data,
        };
    }

    fn getInstCode(self: Self) u4 {
        return @truncate(u4, self.data >> 11) & 0b1111;
    }

    fn getReg1Id(self: Self) u3 {
        return @truncate(u3, self.data >> 8) & (0b111);
    }

    fn getReg2Id(self: Self) u3 {
        return @truncate(u3, self.data >> 5) & (0b111);
    }

    fn getData(self: Self) u8 {
        return @truncate(u8, self.data & 0b11111111);
    }
};

pub const InstSet = union(enum) {
    Mov: MovInst,
    Add: AddInst,
    Sub: SubInst,
    And: AndInst,
    Or: OrInst,
    Sl: SlInst,
    Sr: SrInst,
    Sra: SraInst,
    Ldl: LdlInst,
    Ldh: LdhInst,
    Cmp: CmpInst,
    Je: JeInst,
    Jmp: JmpInst,
    Ld: LdInst,
    St: StInst,
    Hlt: HltInst,

    // for debug
    pub fn print(self: @This()) void {
        switch (self) {
            .Mov => |mov| {
                std.debug.warn("mov reg{} reg{}\n", mov.reg1, mov.reg2);
            },
            .Add => |add| {
                std.debug.warn("add reg{} reg{}\n", add.reg1, add.reg2);
            },
            .Sub => |sub| {
                std.debug.warn("sub reg{} reg{}\n", sub.reg1, sub.reg2);
            },
            .And => |a| {
                std.debug.warn("and reg{} reg{}\n", a.reg1, a.reg2);
            },
            .Or => |o| {
                std.debug.warn("or reg{} reg{}\n", o.reg1, o.reg2);
            },
            .Sl => |sl| {
                std.debug.warn("sl reg{}\n", sl.reg1);
            },
            .Sr => |sr| {
                std.debug.warn("sr reg{}\n", sr.reg1);
            },
            .Sra => |sra| {
                std.debug.warn("sra reg{}\n", sra.reg1);
            },
            .Ldl => |ldl| {
                std.debug.warn("ldl reg{} {}\n", ldl.reg1, ldl.data);
            },
            .Ldh => |ldh| {
                std.debug.warn("ldh reg{} {}\n", ldh.reg1, ldh.data);
            },
            .Cmp => |cmp| {
                std.debug.warn("cmp reg{} reg{}\n", cmp.reg1, cmp.reg2);
            },
            .Je => |je| {
                std.debug.warn("je {}\n", je.addr);
            },
            .Jmp => |jmp| {
                std.debug.warn("jmp {}\n", jmp.addr);
            },
            .Ld => |ld| {
                std.debug.warn("ld reg{} {}\n", ld.reg1, ld.addr);
            },
            .St => |st| {
                std.debug.warn("st reg{} {}\n", st.reg1, st.addr);
            },
            .Hlt => |hlt| {
                std.debug.warn("halt\n");
            },
        }
    }

    const MovInst = struct {
        const op_len = 2;
        reg1: u3,
        reg2: u3,
        
        fn init(reg1: u3, reg2: u3) @This() {
            return @This() {
                .reg1 = reg1,
                .reg2 = reg2,
            };
        }
    };

    const AddInst = struct {
        const op_len = 2;
        reg1: u3,
        reg2: u3,
        
        fn init(reg1: u3, reg2: u3) @This() {
            return @This() {
                .reg1 = reg1,
                .reg2 = reg2,
            };
        }
    };

    const SubInst = struct {
        const op_len = 2;
        reg1: u3,
        reg2: u3,

        fn init(reg1: u3, reg2: u3) @This() {
            return @This() {
                .reg1 = reg1,
                .reg2 = reg2,
            };
        }
    };

    const AndInst = struct {
        const op_len = 2;
        reg1: u3,
        reg2: u3,

        fn init(reg1: u3, reg2: u3) @This() {
            return @This() {
                .reg1 = reg1,
                .reg2 = reg2,
            };
        }
    };

    const OrInst = struct {
        const op_len = 2;
        reg1: u3,
        reg2: u3,

        fn init(reg1: u3, reg2: u3) @This() {
            return @This() {
                .reg1 = reg1,
                .reg2 = reg2,
            };
        }
    };

    const SlInst = struct {
        const op_len = 1;
        reg1: u3,

        fn init(reg1: u3) @This() {
            return @This() {
                .reg1 = reg1,
            };
        }
    };

    const SrInst = struct {
        const op_len = 1;
        reg1: u3,

        fn init(reg1: u3) @This() {
            return @This() {
                .reg1 = reg1,
            };
        }
    };

    const SraInst = struct {
        const op_len = 1;
        reg1: u3,

        fn init(reg1: u3) @This() {
            return @This() {
                .reg1 = reg1,
            };
        }
    };

    const LdlInst = struct {
        const op_len = 2;
        reg1: u3,
        data: u8,

        fn init(reg1: u3, data: u8) @This() {
            return @This() {
                .reg1 = reg1,
                .data = data,
            };
        }
    };

    const LdhInst = struct {
        const op_len = 2;
        reg1: u3,
        data: u8,

        fn init(reg1: u3, data: u8) @This() {
            return @This() {
                .reg1 = reg1,
                .data = data,
            };
        }
    };

    const CmpInst = struct {
        const op_len = 2;
        reg1: u3,
        reg2: u3,

        fn init(reg1: u3, reg2: u3) @This() {
            return @This() {
                .reg1 = reg1,
                .reg2 = reg2,
            };
        }
    };

    const JeInst = struct {
        const op_len = 2;
        addr: u8,

        fn init(addr: u8) @This() {
            return @This() {
                .addr = addr,
            };
        }
    };

    const JmpInst = struct {
        const op_len = 2;
        addr: u8,

        fn init(addr: u8) @This() {
            return @This() {
                .addr = addr,
            };
        }
    };

    const LdInst = struct {
        const op_len = 2;
        reg1: u3,
        addr: u8,

        fn init(reg1: u3, addr: u8) @This() {
            return @This() {
                .reg1 = reg1,
                .addr = addr,
            };
        }
    };

    const StInst = struct {
        const op_len = 2;
        reg1: u3,
        addr: u8,

        fn init(reg1: u3, addr: u8) @This() {
            return @This() {
                .reg1 = reg1,
                .addr = addr,
            };
        }
    };

    const HltInst = struct {
        const op_len = 0;

        fn init() @This() {
            return @This(){};
        }
    };
};