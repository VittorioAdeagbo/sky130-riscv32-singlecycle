// alu_tb.v
// Standalone testbench for alu.v. Vectors were computed against a
// Python reference model (gen_alu_vectors.py) rather than hand-derived,
// specifically to nail down the signed/unsigned edge cases: SRA must
// sign-extend, SLT is signed, SLTU is unsigned, and shift amounts must
// only use the low 5 bits of operand b.
//
// Run: iverilog -o alu_sim.out rtl/alu.v tb/alu_tb.v && vvp alu_sim.out

`timescale 1ns/1ps

module alu_tb;

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

    reg  [31:0] a, b;
    reg  [3:0]  alu_ctrl;
    wire [31:0] result;
    wire        zero;

    integer errors = 0;

    alu dut (
        .a(a), .b(b), .alu_ctrl(alu_ctrl),
        .result(result), .zero(zero)
    );

    task check(input [255:0] name, input [31:0] got, input [31:0] expected);
        begin
            if (got !== expected) begin
                $display("FAIL: %0s -- got 0x%08h, expected 0x%08h", name, got, expected);
                errors = errors + 1;
            end else begin
                $display("PASS: %0s -- 0x%08h", name, got);
            end
        end
    endtask

    initial begin

        a = 32'h0000000F; b = 32'h0000001B; alu_ctrl = ALU_ADD; #1;
        check("ADD 15+27", result, 32'h0000002A);

        a = 32'h0000000A; b = 32'h0000000F; alu_ctrl = ALU_SUB; #1;
        check("SUB 10-15", result, 32'hFFFFFFFB);

        a = 32'h0000002A; b = 32'h0000002A; alu_ctrl = ALU_SUB; #1;
        check("SUB 42-42 (result)", result, 32'h00000000);
        check("SUB 42-42 (zero flag)", {31'b0, zero}, 32'h00000001);

        a = 32'hF0F0F0F0; b = 32'h0F0F0F0F; alu_ctrl = ALU_AND; #1;
        check("AND", result, 32'h00000000);

        a = 32'hF0F0F0F0; b = 32'h0F0F0F0F; alu_ctrl = ALU_OR; #1;
        check("OR", result, 32'hFFFFFFFF);

        a = 32'hF0F0F0F0; b = 32'h0F0F0F0F; alu_ctrl = ALU_XOR; #1;
        check("XOR", result, 32'hFFFFFFFF);

        // Shift amount must come from only the LOW 5 BITS of b, even
        // though the upper bits here are garbage (0xFFFFFFE4 -> low5=4)
        a = 32'h00000001; b = 32'hFFFFFFE4; alu_ctrl = ALU_SLL; #1;
        check("SLL uses only low 5 bits of shift amount", result, 32'h00000010);

        // SRL: logical shift -- MSB must NOT sign-extend even though a looks negative
        a = 32'h80000000; b = 32'h00000004; alu_ctrl = ALU_SRL; #1;
        check("SRL does not sign-extend", result, 32'h08000000);

        // SRA: arithmetic shift -- MSB MUST sign-extend (the classic Verilog trap)
        a = 32'h80000000; b = 32'h00000004; alu_ctrl = ALU_SRA; #1;
        check("SRA sign-extends", result, 32'hF8000000);

        // SLT: signed compare, -5 < 3 -> true
        a = 32'hFFFFFFFB; b = 32'h00000003; alu_ctrl = ALU_SLT; #1;
        check("SLT -5 < 3 (signed, true)", result, 32'h00000001);

        // SLTU: SAME bit patterns, unsigned compare -- 0xFFFFFFFB is huge unsigned, so false
        a = 32'hFFFFFFFB; b = 32'h00000003; alu_ctrl = ALU_SLTU; #1;
        check("SLTU same bits, unsigned, false", result, 32'h00000000);

        // SLT: two positives, sanity check
        a = 32'h00000003; b = 32'h00000005; alu_ctrl = ALU_SLT; #1;
        check("SLT 3 < 5 (signed, true)", result, 32'h00000001);

        if (errors == 0)
            $display("\nALL TESTS PASSED");
        else
            $display("\n%0d TEST(S) FAILED", errors);

        $finish;
    end

endmodule
