// =============================================================
// tb_divider.v
//   iverilog -o sim_div tb/tb_divider.v rtl/full_adder.v \
//            rtl/ripple_carry_adder.v rtl/adder_subtractor.v rtl/divider.v
//   vvp sim_div
// =============================================================
`timescale 1ns/1ps

module tb_divider;

    localparam WIDTH = 8;
    reg               clk = 0;
    reg               rst_n;
    reg               start;
    reg  [WIDTH-1:0]  dividend, divisor;
    wire [WIDTH-1:0]  quotient, remainder;
    wire              busy, done, div_by_zero;

    integer errors = 0;
    integer k;
    reg [WIDTH-1:0] exp_q, exp_r;

    divider #(.WIDTH(WIDTH)) dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .dividend(dividend), .divisor(divisor),
        .quotient(quotient), .remainder(remainder),
        .busy(busy), .done(done), .div_by_zero(div_by_zero)
    );

    always #5 clk = ~clk;

    task run_div(input [WIDTH-1:0] dv, input [WIDTH-1:0] ds);
        begin
            @(negedge clk);
            dividend = dv;
            divisor  = ds;
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;
            wait (done == 1'b1);
            if (ds == 0) begin
                if (!div_by_zero) begin
                    errors = errors + 1;
                    $display("FAIL DIV: %0d / %0d -> div_by_zero not flagged", dv, ds);
                end
            end else begin
                exp_q = dv / ds;
                exp_r = dv % ds;
                if (quotient !== exp_q || remainder !== exp_r) begin
                    errors = errors + 1;
                    $display("FAIL DIV: %0d / %0d -> q=%0d r=%0d (expected q=%0d r=%0d)",
                              dv, ds, quotient, remainder, exp_q, exp_r);
                end
            end
            @(negedge clk);
        end
    endtask

    initial begin
        rst_n = 0; start = 0; dividend = 0; divisor = 0;
        repeat (3) @(negedge clk);
        rst_n = 1;

        $display("=== divider directed + random test (WIDTH=%0d) ===", WIDTH);
        run_div(8'd100, 8'd7);
        run_div(8'd255, 8'd1);
        run_div(8'd0,   8'd5);
        run_div(8'd7,   8'd100);   // dividend < divisor
        run_div(8'd42,  8'd0);     // divide by zero
        run_div(8'd255, 8'd255);

        for (k = 0; k < 100; k = k + 1) begin
            run_div($random, ($random % 250) + 1); // avoid /0 in random sweep
        end

        if (errors == 0) $display("divider: ALL PASS");
        else              $display("divider: %0d FAILURES", errors);

        $finish;
    end

endmodule
