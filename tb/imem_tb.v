// imem_tb.v
// Standalone testbench for imem.v. Bypasses $readmemh by poking the
// memory array directly via hierarchical reference (dut.mem[i]) --
// fine for unit testing, since we're only verifying the addr->instr
// indexing logic here, not the file-loading mechanism itself.
//
// Run: iverilog -o imem_sim.out rtl/imem.v tb/imem_tb.v && vvp imem_sim.out
//
// NOTE: iverilog will try to $readmemh("program.hex", mem) at time 0
// as part of imem's initial block. If program.hex doesn't exist in
// your working directory, iverilog prints a warning (not a fatal
// error) and leaves mem as all-X, which we then immediately overwrite
// below -- so the warning is expected and harmless for this testbench.
// If you'd rather not see it, create an empty program.hex first:
//   touch program.hex

`timescale 1ns/1ps

module imem_tb;

    reg  [31:0] addr;
    wire [31:0] instr;

    integer errors = 0;

    imem #(.MEM_SIZE_WORDS(16)) dut (
        .addr(addr),
        .instr(instr)
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
        // Poke known values into specific word indices directly.
        dut.mem[0] = 32'h00000013; // nop  (word index 0 -> byte addr 0x00)
        dut.mem[1] = 32'h001081B3; // some instr (word index 1 -> byte addr 0x04)
        dut.mem[2] = 32'hDEADBEEF; // arbitrary bit pattern (word index 2 -> byte addr 0x08)
        dut.mem[5] = 32'h12345678; // word index 5 -> byte addr 0x14

        #1;

        addr = 32'h00000000; #1;
        check("fetch at byte addr 0x00", instr, 32'h00000013);

        addr = 32'h00000004; #1;
        check("fetch at byte addr 0x04", instr, 32'h001081B3);

        addr = 32'h00000008; #1;
        check("fetch at byte addr 0x08", instr, 32'hDEADBEEF);

        addr = 32'h00000014; #1;
        check("fetch at byte addr 0x14 (word index 5)", instr, 32'h12345678);

        if (errors == 0)
            $display("\nALL TESTS PASSED");
        else
            $display("\n%0d TEST(S) FAILED", errors);

        $finish;
    end

endmodule
