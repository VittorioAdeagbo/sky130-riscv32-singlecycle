// regfile_tb.v
// Standalone testbench for regfile.v.
// Run: iverilog -o regfile_sim.out rtl/regfile.v tb/regfile_tb.v && vvp regfile_sim.out

`timescale 1ns/1ps

module regfile_tb;

    reg clk;
    reg reset;
    reg RegWrite;
    reg [4:0] rs1_addr, rs2_addr, rd_addr;
    reg [31:0] rd_data;
    wire [31:0] rs1_data, rs2_data;

    integer errors = 0;

    regfile dut (
        .clk(clk),
        .reset(reset),
        .RegWrite(RegWrite),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rd_addr(rd_addr),
        .rd_data(rd_data),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data)
    );

    // 10ns clock period
    always #5 clk = ~clk;

    task check32(input [255:0] name, input [31:0] got, input [31:0] expected);
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
        reset = 1;
        RegWrite = 0;
        rs1_addr = 0; rs2_addr = 0; rd_addr = 0; rd_data = 0;

        // Hold reset for one clock edge
        @(posedge clk);
        @(posedge clk);
        reset = 0;

        // Test 1: x0 always reads zero, even without ever writing it,
        // and even if we try to write it.
        @(negedge clk);
        RegWrite = 1;
        rd_addr  = 5'd0;
        rd_data  = 32'hDEADBEEF;
        @(posedge clk); // attempted write to x0 happens here
        @(negedge clk);
        RegWrite = 0;
        rs1_addr = 5'd0;
        #1;
        check32("x0 read after attempted write", rs1_data, 32'h00000000);

        // Test 2: basic write then read on a later cycle (the normal,
        // supported case -- write on cycle N, read visible on cycle N+1).
        @(negedge clk);
        RegWrite = 1;
        rd_addr  = 5'd5;
        rd_data  = 32'h00000123;
        @(posedge clk); // write to x5 happens here
        @(negedge clk);
        RegWrite = 0;
        rs1_addr = 5'd5;
        #1;
        check32("x5 read after write (next cycle)", rs1_data, 32'h00000123);

        // Test 3: write-then-read in the SAME cycle should NOT see the
        // new value -- this confirms the module has no accidental
        // write-through/forwarding, matching single-cycle CPU expectations.
        @(negedge clk);
        RegWrite = 1;
        rd_addr  = 5'd6;
        rd_data  = 32'hAAAAAAAA;
        rs2_addr = 5'd6; // read the same address we're writing, same cycle
        #1;
        check32("x6 read DURING write (should still be old value, 0)", rs2_data, 32'h00000000);
        @(posedge clk); // now the write actually lands

        @(negedge clk);
        RegWrite = 0;
        rs2_addr = 5'd6;
        #1;
        check32("x6 read after write landed", rs2_data, 32'hAAAAAAAA);

        // Test 4: two simultaneous reads (rs1 and rs2) from different regs
        @(negedge clk);
        RegWrite = 1;
        rd_addr = 5'd10; rd_data = 32'h00000010;
        @(posedge clk);
        @(negedge clk);
        RegWrite = 1;
        rd_addr = 5'd11; rd_data = 32'h00000011;
        @(posedge clk);
        @(negedge clk);
        RegWrite = 0;
        rs1_addr = 5'd10;
        rs2_addr = 5'd11;
        #1;
        check32("dual-port read rs1 (x10)", rs1_data, 32'h00000010);
        check32("dual-port read rs2 (x11)", rs2_data, 32'h00000011);

        if (errors == 0)
            $display("\nALL TESTS PASSED");
        else
            $display("\n%0d TEST(S) FAILED", errors);

        $finish;
    end

endmodule
