// =============================================================
// tb_addsub.v
// Self-checking testbench for full_adder, ripple_carry_adder and
// adder_subtractor. Run with:
//   iverilog -o sim_addsub tb/tb_addsub.v rtl/full_adder.v \
//            rtl/ripple_carry_adder.v rtl/adder_subtractor.v
//   vvp sim_addsub
// =============================================================
`timescale 1ns/1ps

module tb_addsub;

    // ---------------- full_adder: exhaustive 8-case check ----------------
    reg  fa_a, fa_b, fa_cin;
    wire fa_sum, fa_cout;
    integer i;
    integer fa_errors = 0;

    full_adder dut_fa (.a(fa_a), .b(fa_b), .cin(fa_cin), .sum(fa_sum), .cout(fa_cout));

    // ---------------- adder_subtractor: WIDTH=8 -----------------------------
    localparam WIDTH = 8;
    reg  [WIDTH-1:0] a, b;
    reg              sub;
    wire [WIDTH-1:0] result;
    wire             cout, overflow;
    integer as_errors = 0;
    reg  [WIDTH:0] expected_wide;   // WIDTH+1 bits to capture carry

    adder_subtractor #(.WIDTH(WIDTH)) dut_as (
        .a(a), .b(b), .sub(sub),
        .result(result), .cout(cout), .overflow(overflow)
    );

    integer k;

    initial begin
        $display("=== full_adder exhaustive test ===");
        for (i = 0; i < 8; i = i + 1) begin
            {fa_a, fa_b, fa_cin} = i[2:0];
            #1;
            if ({fa_cout, fa_sum} !== (fa_a + fa_b + fa_cin)) begin
                fa_errors = fa_errors + 1;
                $display("FAIL full_adder: a=%b b=%b cin=%b -> sum=%b cout=%b (expected %b)",
                          fa_a, fa_b, fa_cin, fa_sum, fa_cout, (fa_a+fa_b+fa_cin));
            end
        end
        if (fa_errors == 0) $display("full_adder: ALL PASS (8/8)");
        else                $display("full_adder: %0d FAILURES", fa_errors);

        $display("\n=== adder_subtractor directed + random test (WIDTH=%0d) ===", WIDTH);

        // Directed cases
        test_add(8'd10, 8'd20);
        test_add(8'd255, 8'd1);      // wraps
        test_add(8'd0, 8'd0);
        test_sub(8'd20, 8'd10);
        test_sub(8'd10, 8'd20);      // underflow / borrow
        test_sub(8'd0, 8'd0);
        test_sub(8'd255, 8'd255);

        // Random cases
        for (k = 0; k < 200; k = k + 1) begin
            test_add($random, $random);
            test_sub($random, $random);
        end

        if (as_errors == 0) $display("adder_subtractor: ALL PASS");
        else                $display("adder_subtractor: %0d FAILURES", as_errors);

        $display("\n=== SUMMARY ===");
        if (fa_errors == 0 && as_errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED (fa=%0d, addsub=%0d)", fa_errors, as_errors);

        $finish;
    end

    task test_add(input [WIDTH-1:0] av, input [WIDTH-1:0] bv);
        begin
            a = av; b = bv; sub = 1'b0; #1;
            expected_wide = av + bv;
            if (result !== expected_wide[WIDTH-1:0] || cout !== expected_wide[WIDTH]) begin
                as_errors = as_errors + 1;
                $display("FAIL ADD: %0d + %0d -> result=%0d cout=%b (expected %0d, cout %b)",
                          av, bv, result, cout, expected_wide[WIDTH-1:0], expected_wide[WIDTH]);
            end
        end
    endtask

    task test_sub(input [WIDTH-1:0] av, input [WIDTH-1:0] bv);
        reg [WIDTH-1:0] exp_result;
        reg             exp_no_borrow;
        begin
            a = av; b = bv; sub = 1'b1; #1;
            exp_result    = av - bv;               // Verilog wraps like two's complement
            exp_no_borrow = (av >= bv);
            if (result !== exp_result || cout !== exp_no_borrow) begin
                as_errors = as_errors + 1;
                $display("FAIL SUB: %0d - %0d -> result=%0d cout(no_borrow)=%b (expected %0d, %b)",
                          av, bv, result, cout, exp_result, exp_no_borrow);
            end
        end
    endtask

endmodule
