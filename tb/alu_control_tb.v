// alu_control_tb.v
// Standalone testbench for alu_control.v. The critical test here is
// "addi with imm bit 30 set does NOT decode as SUB" -- see the header
// comment in alu_control.v for why this is a real, easy-to-miss bug.
//
// Run: iverilog -o alu_control_sim.out rtl/alu_control.v tb/alu_control_tb.v && vvp alu_control_sim.out

`timescale 1ns/1ps

module alu_control_tb;

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

    reg  [1:0] ALUOp;
    reg  [2:0] funct3;
    reg        funct7b5;
    reg        is_rtype;
    wire [3:0] alu_ctrl;

    integer errors = 0;

    alu_control dut (
        .ALUOp(ALUOp), .funct3(funct3), .funct7b5(funct7b5), .is_rtype(is_rtype),
        .alu_ctrl(alu_ctrl)
    );

    task check(input [255:0] name, input [3:0] got, input [3:0] expected);
        begin
            if (got !== expected) begin
                $display("FAIL: %0s -- got %b, expected %b", name, got, expected);
                errors = errors + 1;
            end else begin
                $display("PASS: %0s -- %b", name, got);
            end
        end
    endtask

    initial begin

        // R-type add: funct3=000, funct7b5=0, is_rtype=1
        ALUOp = 2'b10; funct3 = 3'b000; funct7b5 = 1'b0; is_rtype = 1'b1; #1;
        check("R-type add", alu_ctrl, ALU_ADD);

        // R-type sub: funct3=000, funct7b5=1, is_rtype=1
        ALUOp = 2'b10; funct3 = 3'b000; funct7b5 = 1'b1; is_rtype = 1'b1; #1;
        check("R-type sub", alu_ctrl, ALU_SUB);

        // THE TRAP CASE: addi with imm bit 30 set -- funct3=000,
        // funct7b5=1 (coincidentally, from the immediate bits),
        // is_rtype=0. Must decode as ADD, not SUB.
        ALUOp = 2'b10; funct3 = 3'b000; funct7b5 = 1'b1; is_rtype = 1'b0; #1;
        check("addi with imm[10]=1 (looks like sub, must stay ADD)", alu_ctrl, ALU_ADD);

        // R-type shifts: srl vs sra disambiguation, no is_rtype gating needed
        ALUOp = 2'b10; funct3 = 3'b101; funct7b5 = 1'b0; is_rtype = 1'b1; #1;
        check("srl (funct7b5=0)", alu_ctrl, ALU_SRL);

        ALUOp = 2'b10; funct3 = 3'b101; funct7b5 = 1'b1; is_rtype = 1'b1; #1;
        check("sra (funct7b5=1)", alu_ctrl, ALU_SRA);

        // I-type shift-immediate: same disambiguation, is_rtype=0, should still work
        ALUOp = 2'b10; funct3 = 3'b101; funct7b5 = 1'b0; is_rtype = 1'b0; #1;
        check("srli (I-type, funct7b5=0)", alu_ctrl, ALU_SRL);

        ALUOp = 2'b10; funct3 = 3'b101; funct7b5 = 1'b1; is_rtype = 1'b0; #1;
        check("srai (I-type, funct7b5=1)", alu_ctrl, ALU_SRA);

        // Remaining R/I-type ops, spot check
        ALUOp = 2'b10; funct3 = 3'b010; funct7b5 = 1'b0; is_rtype = 1'b1; #1;
        check("slt", alu_ctrl, ALU_SLT);

        ALUOp = 2'b10; funct3 = 3'b111; funct7b5 = 1'b0; is_rtype = 1'b1; #1;
        check("and", alu_ctrl, ALU_AND);

        // Branches
        ALUOp = 2'b01; funct3 = 3'b000; funct7b5 = 1'bx; is_rtype = 1'bx; #1; // beq
        check("beq -> SUB", alu_ctrl, ALU_SUB);

        ALUOp = 2'b01; funct3 = 3'b100; funct7b5 = 1'bx; is_rtype = 1'bx; #1; // blt
        check("blt -> SLT", alu_ctrl, ALU_SLT);

        ALUOp = 2'b01; funct3 = 3'b110; funct7b5 = 1'bx; is_rtype = 1'bx; #1; // bltu
        check("bltu -> SLTU", alu_ctrl, ALU_SLTU);

        // Loads/stores/jalr
        ALUOp = 2'b00; funct3 = 3'bxxx; funct7b5 = 1'bx; is_rtype = 1'bx; #1;
        check("load/store/jalr -> ADD", alu_ctrl, ALU_ADD);

        if (errors == 0)
            $display("\nALL TESTS PASSED");
        else
            $display("\n%0d TEST(S) FAILED", errors);

        $finish;
    end

endmodule
