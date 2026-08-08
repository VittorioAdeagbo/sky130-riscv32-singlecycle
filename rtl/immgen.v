// immgen.v
// RV32I immediate generator.
// Takes the raw 32-bit instruction, decodes which format it is from the
// opcode field, and produces the correctly-assembled, sign-extended
// 32-bit immediate value.
//
// Bit layouts (from the RISC-V unprivileged ISA spec, ch. 2), all as
// [instruction bit range] -> [immediate bit range]:
//
//   I-type: instr[31:20]                                  -> imm[11:0]
//   S-type: instr[31:25],instr[11:7]                       -> imm[11:5],imm[4:0]
//   B-type: instr[31],instr[7],instr[30:25],instr[11:8],0  -> imm[12],imm[11],imm[10:5],imm[4:1],imm[0]
//   U-type: instr[31:12],12'b0                              -> imm[31:12],imm[11:0]
//   J-type: instr[31],instr[19:12],instr[20],instr[30:21],0 -> imm[20],imm[19:12],imm[11],imm[10:1],imm[0]
//
// B-type and J-type both have an implicit LSB of 0 (branch/jump targets
// are always 2-byte aligned, so that bit isn't stored in the encoding --
// it's the single easiest thing to forget here).
//
// All immediates are sign-extended to 32 bits from their most-significant
// stored bit (instr[31] for I/S/B/J, since instr[31] is always the sign
// bit in this ISA's encoding; U-type doesn't need extension since it
// fills all 32 bits already, upper 12 from instr[31:12] and lower 20 zero).

module immgen (
    input  wire [31:0] instr,
    output reg  [31:0] imm
);

    // Opcodes needed to distinguish format (see /docs/isa-subset.md)
    localparam OPC_LOAD   = 7'b0000011; // I-type (load)
    localparam OPC_ALUIMM = 7'b0010011; // I-type (addi, slti, etc.)
    localparam OPC_JALR   = 7'b1100111; // I-type (jalr)
    localparam OPC_STORE  = 7'b0100011; // S-type
    localparam OPC_BRANCH = 7'b1100011; // B-type
    localparam OPC_LUI    = 7'b0110111; // U-type
    localparam OPC_AUIPC  = 7'b0010111; // U-type
    localparam OPC_JAL    = 7'b1101111; // J-type

    wire [6:0] opcode = instr[6:0];

    always @(*) begin
        case (opcode)

            OPC_LOAD, OPC_ALUIMM, OPC_JALR: begin
                // I-type: imm[11:0] = instr[31:20], sign-extend from bit 31
                imm = {{20{instr[31]}}, instr[31:20]};
            end

            OPC_STORE: begin
                // S-type: imm[11:5] = instr[31:25], imm[4:0] = instr[11:7]
                imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            end

            OPC_BRANCH: begin
                // B-type: imm[12]=instr[31], imm[11]=instr[7],
                //         imm[10:5]=instr[30:25], imm[4:1]=instr[11:8], imm[0]=0
                imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
            end

            OPC_LUI, OPC_AUIPC: begin
                // U-type: imm[31:12] = instr[31:12], imm[11:0] = 0
                // No sign extension needed -- already fills all 32 bits.
                imm = {instr[31:12], 12'b0};
            end

            OPC_JAL: begin
                // J-type: imm[20]=instr[31], imm[19:12]=instr[19:12],
                //         imm[11]=instr[20], imm[10:1]=instr[30:21], imm[0]=0
                imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
            end

            default: begin
                // R-type (and anything unrecognized) has no immediate.
                // Drive to zero rather than leaving it 'x -- keeps
                // downstream muxes/waveforms clean even when ImmSrc
                // wouldn't select this path anyway.
                imm = 32'd0;
            end

        endcase
    end

endmodule
