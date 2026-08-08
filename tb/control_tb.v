// control_tb.v
// Standalone testbench for control.v -- checks the main decoder's
// output signals for one representative instruction of each opcode class.
//
// Run: iverilog -o control_sim.out rtl/control.v tb/control_tb.v && vvp control_sim.out

`timescale 1ns/1ps

module control_tb;

    reg  [6:0] opcode;
    wire RegWrite, ALUSrc, MemWrite, Branch, Jump;
    wire [2:0] ResultSrc;
    wire [1:0] ALUOp;

    integer errors = 0;

    control dut (
        .opcode(opcode),
        .RegWrite(RegWrite), .ALUSrc(ALUSrc), .MemWrite(MemWrite),
        .ResultSrc(ResultSrc), .Branch(Branch), .Jump(Jump), .ALUOp(ALUOp)
    );

    task check_bit(input [255:0] name, input got, input expected);
        begin
            if (got !== expected) begin
                $display("FAIL: %0s -- got %b, expected %b", name, got, expected);
                errors = errors + 1;
            end else begin
                $display("PASS: %0s -- %b", name, got);
            end
        end
    endtask

    task check_vec(input [255:0] name, input [7:0] got, input [7:0] expected);
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

        // R-type
        opcode = 7'b0110011; #1;
        check_bit("R-type RegWrite", RegWrite, 1'b1);
        check_bit("R-type ALUSrc",   ALUSrc,   1'b0);
        check_vec("R-type ResultSrc", ResultSrc, 3'b000);
        check_vec("R-type ALUOp",     ALUOp,     2'b10);

        // I-type ALU (addi etc.)
        opcode = 7'b0010011; #1;
        check_bit("I-type RegWrite", RegWrite, 1'b1);
        check_bit("I-type ALUSrc",   ALUSrc,   1'b1);
        check_vec("I-type ALUOp",    ALUOp,    2'b10);

        // Load
        opcode = 7'b0000011; #1;
        check_bit("Load RegWrite",  RegWrite, 1'b1);
        check_bit("Load ALUSrc",    ALUSrc,   1'b1);
        check_vec("Load ResultSrc", ResultSrc, 3'b001);
        check_vec("Load ALUOp",     ALUOp,     2'b00);

        // Store
        opcode = 7'b0100011; #1;
        check_bit("Store RegWrite", RegWrite, 1'b0);
        check_bit("Store MemWrite", MemWrite, 1'b1);
        check_vec("Store ALUOp",    ALUOp,    2'b00);

        // Branch
        opcode = 7'b1100011; #1;
        check_bit("Branch RegWrite", RegWrite, 1'b0);
        check_bit("Branch Branch",   Branch,   1'b1);
        check_vec("Branch ALUOp",    ALUOp,    2'b01);

        // JAL
        opcode = 7'b1101111; #1;
        check_bit("JAL RegWrite",  RegWrite, 1'b1);
        check_bit("JAL Jump",      Jump,     1'b1);
        check_vec("JAL ResultSrc", ResultSrc, 3'b010);

        // JALR
        opcode = 7'b1100111; #1;
        check_bit("JALR RegWrite",  RegWrite, 1'b1);
        check_bit("JALR ALUSrc",    ALUSrc,   1'b1);
        check_bit("JALR Jump",      Jump,     1'b1);
        check_vec("JALR ResultSrc", ResultSrc, 3'b010);
        check_vec("JALR ALUOp",     ALUOp,     2'b00);

        // LUI
        opcode = 7'b0110111; #1;
        check_bit("LUI RegWrite",  RegWrite, 1'b1);
        check_vec("LUI ResultSrc", ResultSrc, 3'b100);

        // AUIPC
        opcode = 7'b0010111; #1;
        check_bit("AUIPC RegWrite",  RegWrite, 1'b1);
        check_vec("AUIPC ResultSrc", ResultSrc, 3'b011);

        if (errors == 0)
            $display("\nALL TESTS PASSED");
        else
            $display("\n%0d TEST(S) FAILED", errors);

        $finish;
    end

endmodule
