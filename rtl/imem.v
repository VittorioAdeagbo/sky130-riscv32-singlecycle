// imem.v
// Instruction memory. Combinational read only (no clock) -- correct for
// a single-cycle design, where fetch has to produce an instruction the
// same cycle PC changes, with no register stage in between.
//
// Addressed by PC as a BYTE address (RISC-V convention -- PC always
// increments by 4, and byte-addressability matters later for jalr/jal
// targets), but the memory itself is a 32-bit-wide word array, so we
// drop the low 2 bits of the address to get the word index. If PC is
// ever misaligned (addr[1:0] != 00), that's a real error condition in
// your CPU logic upstream -- this module doesn't check for it, it just
// silently ignores those two bits, which is standard for this kind of
// simple model but worth knowing if you ever see garbled instructions
// during debug: check PC alignment first.

module imem #(
    parameter MEM_SIZE_WORDS = 1024  // 4KB of instruction memory by default
) (
    input  wire [31:0] addr,
    output wire [31:0] instr
);

    reg [31:0] mem [0:MEM_SIZE_WORDS-1];

    // Replace "program.hex" with your actual test program file when you
    // wire this into cpu_top / the CPU-level testbench. Loaded once at
    // time 0. Format: one 32-bit hex value per line, e.g. "00000013"
    // for a nop (addi x0,x0,0).
    initial begin
        $readmemh("program.hex", mem);
    end

    assign instr = mem[addr[31:2]];

endmodule
