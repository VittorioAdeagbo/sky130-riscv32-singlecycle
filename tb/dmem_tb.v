// dmem_tb.v
// Standalone testbench for dmem.v. Covers all five load funct3 codes
// against stored data, specifically checking sign-extension (lb/lh)
// vs zero-extension (lbu/lhu) on the SAME underlying bit pattern, plus
// a check that a byte/half store doesn't corrupt neighboring bytes.
//
// Run: iverilog -o dmem_sim.out rtl/dmem.v tb/dmem_tb.v && vvp dmem_sim.out

`timescale 1ns/1ps

module dmem_tb;

    reg         clk;
    reg         MemWrite;
    reg  [31:0] addr;
    reg  [31:0] write_data;
    reg  [2:0]  funct3;
    wire [31:0] read_data;

    integer errors = 0;

    dmem #(.MEM_SIZE_BYTES(64)) dut (
        .clk(clk), .MemWrite(MemWrite), .addr(addr),
        .write_data(write_data), .funct3(funct3), .read_data(read_data)
    );

    always #5 clk = ~clk;

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
        clk = 0;
        MemWrite = 0;
        addr = 0; write_data = 0; funct3 = 0;

        // --- sw / lw roundtrip ---
        @(negedge clk);
        MemWrite = 1; addr = 8; write_data = 32'hDEADBEEF; funct3 = 3'b010; // sw
        @(posedge clk);
        @(negedge clk);
        MemWrite = 0; addr = 8; funct3 = 3'b010; // lw
        #1;
        check("sw/lw roundtrip", read_data, 32'hDEADBEEF);

        // --- little-endian byte order check: byte at addr+0 should be LSB ---
        @(negedge clk);
        MemWrite = 0; addr = 8; funct3 = 3'b000; // lb at base addr -> LSB of 0xDEADBEEF is 0xEF
        #1;
        // 0xEF = 11101111 -- bit 7 is SET, so as a signed byte this is
        // negative and lb correctly sign-extends it to 0xFFFFFFEF.
        // (Use lbu below if you want to see the same byte read as +239.)
        check("little-endian: LSB at base address (signed, negative)", read_data, 32'hFFFFFFEF);

        // --- sb / lb with sign extension: store 0xFF (i.e. -1 as signed byte) ---
        @(negedge clk);
        MemWrite = 1; addr = 0; write_data = 32'h000000FF; funct3 = 3'b000; // sb
        @(posedge clk);
        @(negedge clk);
        MemWrite = 0; addr = 0; funct3 = 3'b000; // lb (signed)
        #1;
        check("lb sign-extends 0xFF to -1", read_data, 32'hFFFFFFFF);

        // --- same stored byte, but lbu should zero-extend instead ---
        @(negedge clk);
        MemWrite = 0; addr = 0; funct3 = 3'b100; // lbu (unsigned)
        #1;
        check("lbu zero-extends 0xFF to 255", read_data, 32'h000000FF);

        // --- sh / lh with sign extension: store 0x8000 (negative as signed half) ---
        @(negedge clk);
        MemWrite = 1; addr = 20; write_data = 32'h00008000; funct3 = 3'b001; // sh
        @(posedge clk);
        @(negedge clk);
        MemWrite = 0; addr = 20; funct3 = 3'b001; // lh (signed)
        #1;
        check("lh sign-extends 0x8000", read_data, 32'hFFFF8000);

        // --- same stored half, lhu should zero-extend instead ---
        @(negedge clk);
        MemWrite = 0; addr = 20; funct3 = 3'b101; // lhu (unsigned)
        #1;
        check("lhu zero-extends 0x8000", read_data, 32'h00008000);

        // --- adjacent-byte non-corruption: write a byte at addr 30,
        //     confirm addr 29 and 31 (pre-loaded via sw) are untouched ---
        @(negedge clk);
        MemWrite = 1; addr = 28; write_data = 32'h11223344; funct3 = 3'b010; // sw at 28..31
        @(posedge clk);
        @(negedge clk);
        MemWrite = 1; addr = 30; write_data = 32'h000000AA; funct3 = 3'b000; // sb at 30 only
        @(posedge clk);
        @(negedge clk);
        MemWrite = 0; addr = 28; funct3 = 3'b010; // lw across 28..31
        #1;
        // byte 30 (3rd byte, bits [23:16]) should now be 0xAA; bytes 28,29,31 unchanged (0x44,0x33,0x11)
        check("sb doesn't corrupt neighboring bytes", read_data, 32'h11AA3344);

        if (errors == 0)
            $display("\nALL TESTS PASSED");
        else
            $display("\n%0d TEST(S) FAILED", errors);

        $finish;
    end

endmodule
