// alu_control.v
// Second-level decoder: takes the coarse ALUOp from control.v plus the
// instruction's funct3/funct7 fields and produces the exact 4-bit
// alu_ctrl code that alu.v expects.
//
// THE CLASSIC BUG THIS MODULE MUST AVOID:
// For funct3=000, R-type distinguishes add (funct7=0000000) from sub
// (funct7=0100000) using instr[30]. But for I-type ALU-immediate
// instructions (addi), instr[31:20] IS the immediate field -- there is
// no funct7. If an addi's immediate happens to have bit 30 set (e.g.
// addi with immediate 0x400 or any value >= 1024), instr[30] will be
// '1' by pure coincidence, and a decoder that doesn't check "is this
// actually R-type?" first will wrongly decode addi as a subtract.
// This bug will not show up in simple tests (addi x1, x0, 5) and will
// only appear with specific immediate values -- exactly the kind of
// thing that passes initial testing and then breaks later. We gate on
// is_rtype (derived from opcode bit 5) explicitly below.
//
// The srli/srai case is different and does NOT need this gating: the
// RISC-V spec deliberately defines shift-immediate instructions so
// that instr[30] genuinely IS the intended srli/srai selector (the
// spec reserves imm[10:5] must be 0 and imm[11] unused for these,
// with bit 30 specifically carrying that meaning) -- so checking
// instr[30] directly for funct3=101 is correct for both R-type and
// I-type without needing the is_rtype gate.

module alu_control (
    input  wire [1:0] ALUOp,
    input  wire [2:0] funct3,
    input  wire        funct7b5,   // instr[30]
    input  wire        is_rtype,   // instr[5] -- 1 for R-type, 0 for I-type-ALU
    output reg  [3:0]  alu_ctrl
);

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

    always @(*) begin
        case (ALUOp)

            2'b00: alu_ctrl = ALU_ADD; // loads/stores/jalr address calc

            2'b01: begin // branch: funct3 picks the comparison
                case (funct3)
                    3'b000, 3'b001: alu_ctrl = ALU_SUB;  // beq/bne -> zero flag
                    3'b100, 3'b101: alu_ctrl = ALU_SLT;  // blt/bge -> signed compare
                    3'b110, 3'b111: alu_ctrl = ALU_SLTU; // bltu/bgeu -> unsigned compare
                    default:        alu_ctrl = ALU_SUB;
                endcase
            end

            2'b10: begin // R-type / I-type ALU ops
                case (funct3)
                    3'b000: alu_ctrl = (is_rtype && funct7b5) ? ALU_SUB : ALU_ADD; // add / addi / sub (gated!)
                    3'b001: alu_ctrl = ALU_SLL;
                    3'b010: alu_ctrl = ALU_SLT;
                    3'b011: alu_ctrl = ALU_SLTU;
                    3'b100: alu_ctrl = ALU_XOR;
                    3'b101: alu_ctrl = funct7b5 ? ALU_SRA : ALU_SRL; // no gating needed, see header comment
                    3'b110: alu_ctrl = ALU_OR;
                    3'b111: alu_ctrl = ALU_AND;
                    default: alu_ctrl = ALU_ADD;
                endcase
            end

            default: alu_ctrl = ALU_ADD;

        endcase
    end

endmodule
