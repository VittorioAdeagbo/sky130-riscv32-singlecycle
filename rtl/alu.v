// alu.v
// RV32I ALU. Combinational: given two 32-bit operands and a 4-bit
// operation select, produces a 32-bit result plus a zero flag.
//
// Operand widths and signedness are the two places this module is easy
// to get subtly wrong:
//  - `sra` (arithmetic right shift) must sign-extend. In Verilog, `>>>`
//    only does an arithmetic shift if its LEFT operand is declared
//    `signed` -- on a plain `wire`/`reg` it silently behaves exactly
//    like `>>` (logical shift), with no warning. We declare a signed
//    view of operand A specifically for this.
//  - `slt` (set-less-than) is a SIGNED comparison; `sltu` is UNSIGNED.
//    Comparing two `wire [31:0]` with `<` in Verilog is unsigned by
//    default, so `slt` needs an explicit signed comparison, again via
//    a signed view of the operands.
//  - Shift amounts (`sll`/`srl`/`sra`) only use the low 5 bits of
//    operand B (shifts are mod 32 for a 32-bit datapath) -- instr[24:20]
//    for the R-type shifts, or imm[4:0] for the I-type shift-immediates.
//    The immediate generator already sign-extends the *whole* I-type
//    immediate, so we must only take bits [4:0] of operand B here,
//    not use all 32 bits as the shift amount.

module alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  alu_ctrl,
    output reg  [31:0] result,
    output wire         zero
);

    // ALU control encoding (matches what the ALU-control decoder,
    // built from opcode+funct3+funct7, will drive):
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLL  = 4'b0101;
    localparam ALU_SRL  = 4'b0110;
    localparam ALU_SRA  = 4'b0111;
    localparam ALU_SLT  = 4'b1000;
    localparam ALU_SLTU = 4'b1001;

    // Signed views, used only where signed arithmetic is required.
    wire signed [31:0] a_signed = a;
    wire signed [31:0] b_signed = b;

    // Shift amount: only the low 5 bits of b matter for a 32-bit shift.
    wire [4:0] shamt = b[4:0];

    always @(*) begin
        case (alu_ctrl)
            ALU_ADD:  result = a + b;
            ALU_SUB:  result = a - b;
            ALU_AND:  result = a & b;
            ALU_OR:   result = a | b;
            ALU_XOR:  result = a ^ b;
            ALU_SLL:  result = a << shamt;
            ALU_SRL:  result = a >> shamt;
            ALU_SRA:  result = a_signed >>> shamt;              // arithmetic shift needs signed operand
            ALU_SLT:  result = (a_signed < b_signed) ? 32'd1 : 32'd0;  // signed compare
            ALU_SLTU: result = (a < b)               ? 32'd1 : 32'd0;  // unsigned compare
            default:  result = 32'd0;
        endcase
    end

    // Used by the branch comparator path for beq/bne (result==0 check
    // after a SUB), and can double as part of the branch-taken logic
    // for other branch types depending on how you wire cpu_top.
    assign zero = (result == 32'd0);

endmodule
