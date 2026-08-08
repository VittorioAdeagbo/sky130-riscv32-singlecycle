// control.v
// Main decoder: combinational, decodes the instruction opcode into the
// high-level control signals that drive muxes throughout the datapath.
// This is a direct transcription of /docs/isa-subset.md -- if you ever
// add/remove an instruction, update that table first, then this case
// statement to match.
//
// ResultSrc selects what gets written back to rd:
//   000 = ALU result           (R-type, I-type ALU ops, jalr's address calc unused here)
//   001 = Data memory read     (loads)
//   010 = PC + 4               (jal, jalr -- the "return address"/link value)
//   011 = PC + immediate       (auipc)
//   100 = immediate itself     (lui)
//
// ALUOp tells the ALU-control decoder (alu_control.v) which class of
// operation this is, so IT can look at funct3/funct7 appropriately:
//   00 = ADD            (loads/stores address calc, jalr target calc)
//   01 = branch compare (funct3 picks sub/slt/sltu -- see alu_control.v)
//   10 = R-type/I-type  (funct3 [+funct7 for R-type] picks the exact op)
//
// NOTE for datapath wiring (next step, cpu_top.v): this module does NOT
// decide whether a jump target comes from the PC+imm adder (jal) or the
// ALU result rs1+imm (jalr) -- that's a plain opcode check you'll do
// directly in cpu_top, since Jump=1 for both but the source differs.

module control (
    input  wire [6:0] opcode,
    output reg         RegWrite,
    output reg         ALUSrc,     // 0 = rs2, 1 = immediate
    output reg         MemWrite,
    output reg  [2:0]  ResultSrc,
    output reg         Branch,
    output reg         Jump,
    output reg  [1:0]  ALUOp
);

    localparam OPC_RTYPE  = 7'b0110011;
    localparam OPC_ITYPE  = 7'b0010011; // addi, slti, etc.
    localparam OPC_LOAD   = 7'b0000011;
    localparam OPC_STORE  = 7'b0100011;
    localparam OPC_BRANCH = 7'b1100011;
    localparam OPC_JAL    = 7'b1101111;
    localparam OPC_JALR   = 7'b1100111;
    localparam OPC_LUI    = 7'b0110111;
    localparam OPC_AUIPC  = 7'b0010111;

    always @(*) begin
        // Safe defaults -- every signal is explicitly assigned on every
        // branch below, but defaults here mean an unrecognized opcode
        // (e.g. bad instruction memory contents) doesn't accidentally
        // write a register or memory, and Yosys won't infer a latch
        // since every output has a value on every path.
        RegWrite  = 1'b0;
        ALUSrc    = 1'b0;
        MemWrite  = 1'b0;
        ResultSrc = 3'b000;
        Branch    = 1'b0;
        Jump      = 1'b0;
        ALUOp     = 2'b00;

        case (opcode)

            OPC_RTYPE: begin
                RegWrite  = 1'b1;
                ALUSrc    = 1'b0;   // operand B = rs2
                ResultSrc = 3'b000; // ALU result
                ALUOp     = 2'b10;  // funct3/funct7 decide exact op
            end

            OPC_ITYPE: begin
                RegWrite  = 1'b1;
                ALUSrc    = 1'b1;   // operand B = immediate
                ResultSrc = 3'b000;
                ALUOp     = 2'b10;
            end

            OPC_LOAD: begin
                RegWrite  = 1'b1;
                ALUSrc    = 1'b1;   // address = rs1 + imm
                ResultSrc = 3'b001; // writeback = memory read data
                ALUOp     = 2'b00;  // ADD
            end

            OPC_STORE: begin
                ALUSrc    = 1'b1;   // address = rs1 + imm
                MemWrite  = 1'b1;
                ALUOp     = 2'b00;  // ADD
            end

            OPC_BRANCH: begin
                ALUSrc    = 1'b0;   // compare rs1 vs rs2 directly
                Branch    = 1'b1;
                ALUOp     = 2'b01;  // funct3 decides sub/slt/sltu
            end

            OPC_JAL: begin
                RegWrite  = 1'b1;
                ResultSrc = 3'b010; // writeback = PC+4 (link)
                Jump      = 1'b1;
                // ALUSrc/ALUOp irrelevant -- target comes from the
                // PC+imm adder in cpu_top, ALU isn't used for jal.
            end

            OPC_JALR: begin
                RegWrite  = 1'b1;
                ALUSrc    = 1'b1;   // ALU computes rs1 + imm (the target)
                ResultSrc = 3'b010; // writeback = PC+4 (link)
                Jump      = 1'b1;
                ALUOp     = 2'b00;  // ADD
            end

            OPC_LUI: begin
                RegWrite  = 1'b1;
                ResultSrc = 3'b100; // writeback = immediate itself
            end

            OPC_AUIPC: begin
                RegWrite  = 1'b1;
                ResultSrc = 3'b011; // writeback = PC + immediate
            end

            default: begin
                // all defaults above already apply
            end

        endcase
    end

endmodule
