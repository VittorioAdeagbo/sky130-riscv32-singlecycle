// regfile.v
// 32 x 32-bit RISC-V register file (x0..x31)
// - x0 is hardwired to zero: reads always return 0, writes to it are ignored
// - Two combinational (asynchronous) read ports: rs1, rs2
// - One synchronous write port: writes on the rising edge of clk when RegWrite=1
//
// IMPORTANT behavioral note (this is the classic single-cycle bug):
// A write on this cycle is NOT visible to a read in this same cycle.
// The write only takes effect at the clock edge, so any instruction reading
// a register that a *previous* instruction just wrote will correctly see
// the new value (because that write already happened on a prior edge),
// but you should never expect same-cycle write-then-read to forward.
// Single-cycle RISC-V doesn't need forwarding at all -- this is only
// a concern if you accidentally write a testbench that expects it.

module regfile (
    input  wire        clk,
    input  wire         reset,      // synchronous reset, clears all regs to 0 (nice for clean sim)
    input  wire        RegWrite,
    input  wire [4:0]  rs1_addr,
    input  wire [4:0]  rs2_addr,
    input  wire [4:0]  rd_addr,
    input  wire [31:0] rd_data,     // data to write into rd_addr
    output wire [31:0] rs1_data,
    output wire [31:0] rs2_data
);

    reg [31:0] regs [0:31];
    integer i;

    // Asynchronous, combinational reads.
    // x0 is forced to zero regardless of what's stored in regs[0]
    // (we also prevent writes to regs[0] below, but this is a second
    // safety net -- belt and suspenders, since a bug here is invisible
    // in isolated testing but corrupts your whole CPU downstream).
    assign rs1_data = (rs1_addr == 5'd0) ? 32'd0 : regs[rs1_addr];
    assign rs2_data = (rs2_addr == 5'd0) ? 32'd0 : regs[rs2_addr];

    // Synchronous write.
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'd0;
        end else if (RegWrite && (rd_addr != 5'd0)) begin
            regs[rd_addr] <= rd_data;
        end
    end

endmodule
