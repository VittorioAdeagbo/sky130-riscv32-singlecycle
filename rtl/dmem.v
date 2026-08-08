// dmem.v
// Data memory. Byte-addressable (stored as an array of 8-bit cells)
// so byte/halfword/word loads and stores can all be modeled correctly,
// little-endian (RISC-V convention: lowest address = least significant
// byte).
//
// funct3 selects width AND signedness for loads, width only for stores
// (a store never needs to know about sign extension -- it just writes
// however many bytes are given):
//   000 = byte,  signed load (lb)  / any-width-agnostic store (sb)
//   001 = half,  signed load (lh)  / (sh)
//   010 = word                     / (sw)
//   100 = byte,  UNSIGNED load (lbu)  -- store never uses this encoding
//   101 = half,  UNSIGNED load (lhu)  -- store never uses this encoding
//
// Reads are combinational (address -> data_out same cycle), required
// for a single-cycle datapath where the ALU computes the address and
// the load value has to be ready for the writeback mux in that same
// cycle. Writes are synchronous on the clock edge, gated by MemWrite.
//
// Multi-byte accesses read/write bytes at addr, addr+1, addr+2, addr+3
// as needed (little-endian: addr = least significant byte). This
// module does NOT check alignment -- an lh/lw at an odd/non-word
// address will silently read across whatever bytes are there; real
// hardware would trap on this, but modeling that is out of scope here.

module dmem #(
    parameter MEM_SIZE_BYTES = 4096  // 4KB of data memory by default
) (
    input  wire        clk,
    input  wire        MemWrite,
    input  wire [31:0] addr,
    input  wire [31:0] write_data,
    input  wire [2:0]  funct3,
    output reg  [31:0] read_data
);

    reg [7:0] mem [0:MEM_SIZE_BYTES-1];

    // Synchronous write.
    always @(posedge clk) begin
        if (MemWrite) begin
            case (funct3[1:0])  // width only -- bit 2 (signedness) irrelevant for stores
                2'b00: begin // sb
                    mem[addr] <= write_data[7:0];
                end
                2'b01: begin // sh
                    mem[addr]   <= write_data[7:0];
                    mem[addr+1] <= write_data[15:8];
                end
                2'b10: begin // sw
                    mem[addr]   <= write_data[7:0];
                    mem[addr+1] <= write_data[15:8];
                    mem[addr+2] <= write_data[23:16];
                    mem[addr+3] <= write_data[31:24];
                end
                default: ; // no-op, shouldn't happen for a valid store
            endcase
        end
    end

    // Combinational read, with sign/zero extension per funct3.
    always @(*) begin
        case (funct3)
            3'b000: read_data = {{24{mem[addr][7]}}, mem[addr]};                         // lb  (sign-extend)
            3'b001: read_data = {{16{mem[addr+1][7]}}, mem[addr+1], mem[addr]};          // lh  (sign-extend)
            3'b010: read_data = {mem[addr+3], mem[addr+2], mem[addr+1], mem[addr]};      // lw
            3'b100: read_data = {24'b0, mem[addr]};                                      // lbu (zero-extend)
            3'b101: read_data = {16'b0, mem[addr+1], mem[addr]};                         // lhu (zero-extend)
            default: read_data = 32'b0;
        endcase
    end

endmodule
