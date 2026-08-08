// immgen_tb.v
// Standalone testbench for immgen.v.
// Test instruction encodings below were generated programmatically
// (not hand-derived) from the format definitions to avoid transcription
// errors in the testbench itself -- see gen_vectors.py if you want to
// regenerate or extend these.
//
// Run: iverilog -o immgen_sim.out rtl/immgen.v tb/immgen_tb.v && vvp immgen_sim.out

`timescale 1ns/1ps

module immgen_tb;

    reg  [31:0] instr;
    wire [31:0] imm;

    integer errors = 0;

    immgen dut (
        .instr(instr),
        .imm(imm)
    );

    task check(input [255:0] name, input [31:0] got, input [31:0] expected);
        begin
            if (got !== expected) begin
                $display("FAIL: %0s -- instr=0x%08h got imm=0x%08h, expected 0x%08h",
                          name, instr, got, expected);
                errors = errors + 1;
            end else begin
                $display("PASS: %0s -- imm=0x%08h", name, got);
            end
        end
    endtask

    initial begin

        // I-type: addi x1, x0, -5
        instr = 32'hFFB00093; #1;
        check("I-type addi x1,x0,-5", imm, 32'hFFFFFFFB);

        // S-type: sw x2, -4(x1)
        instr = 32'hFE20AE23; #1;
        check("S-type sw x2,-4(x1)", imm, 32'hFFFFFFFC);

        // B-type: beq x3, x4, +8
        instr = 32'h00418463; #1;
        check("B-type beq x3,x4,+8", imm, 32'h00000008);

        // B-type: bne x5, x6, -16  (backward branch, e.g. a loop)
        instr = 32'hFE6298E3; #1;
        check("B-type bne x5,x6,-16", imm, 32'hFFFFFFF0);

        // U-type: lui x7, 0x12345
        instr = 32'h123453B7; #1;
        check("U-type lui x7,0x12345", imm, 32'h12345000);

        // J-type: jal x8, +2048
        instr = 32'h0010046F; #1;
        check("J-type jal x8,+2048", imm, 32'h00000800);

        // J-type: jal x9, -2048
        instr = 32'h801FF4EF; #1;
        check("J-type jal x9,-2048", imm, 32'hFFFFF800);

        // R-type: add x1,x2,x3 -- no immediate field; should drive 0
        instr = 32'h003100B3; #1;
        check("R-type add x1,x2,x3 (no imm)", imm, 32'h00000000);

        if (errors == 0)
            $display("\nALL TESTS PASSED");
        else
            $display("\n%0d TEST(S) FAILED", errors);

        $finish;
    end

endmodule
