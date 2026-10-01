// =============================================================
// tb_multiplier.v
//   iverilog -o sim_mul tb/tb_multiplier.v rtl/full_adder.v \
//            rtl/ripple_carry_adder.v rtl/multiplier.v
//   vvp sim_mul
// =============================================================
`timescale 1ns/1ps

module tb_multiplier;

    localparam WIDTH = 8;
    reg                  clk = 0;
    reg                  rst_n;
    reg                  start;
    reg  [WIDTH-1:0]     multiplicand, multiplier_in;
    wire [2*WIDTH-1:0]   product;
    wire                 busy, done;

    integer errors = 0;
    integer k;
    reg [2*WIDTH-1:0] expected;

    multiplier #(.WIDTH(WIDTH)) dut (
        .clk(clk), .rst_n(rst_n), .start(start),
        .multiplicand(multiplicand), .multiplier_in(multiplier_in),
        .product(product), .busy(busy), .done(done)
    );

    always #5 clk = ~clk;

    task run_mul(input [WIDTH-1:0] mA, input [WIDTH-1:0] mB);
        begin
            @(negedge clk);
            multiplicand  = mA;
            multiplier_in = mB;
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;
            // wait for done (or up to WIDTH+2 cycles as a safety bound)
            wait (done == 1'b1);
            expected = mA * mB;
            if (product !== expected) begin
                errors = errors + 1;
                $display("FAIL MUL: %0d * %0d -> product=%0d (expected %0d)",
                          mA, mB, product, expected);
            end
            @(negedge clk); // let done pulse pass
        end
    endtask

    initial begin
        rst_n = 0; start = 0; multiplicand = 0; multiplier_in = 0;
        repeat (3) @(negedge clk);
        rst_n = 1;

        $display("=== multiplier directed + random test (WIDTH=%0d) ===", WIDTH);
        run_mul(8'd0,   8'd0);
        run_mul(8'd1,   8'd1);
        run_mul(8'd255, 8'd255);
        run_mul(8'd255, 8'd1);
        run_mul(8'd16,  8'd16);
        run_mul(8'd200, 8'd3);

        for (k = 0; k < 100; k = k + 1) begin
            run_mul($random, $random);
        end

        if (errors == 0) $display("multiplier: ALL PASS");
        else              $display("multiplier: %0d FAILURES", errors);

        $finish;
    end

    initial begin
        $dumpfile("multiplier.vcd");
        $dumpvars(0, tb_multiplier);
    end

endmodule
