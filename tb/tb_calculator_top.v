// =============================================================
// tb_calculator_top.v  - full integration test
//   iverilog -o sim_top tb/tb_calculator_top.v rtl/full_adder.v \
//       rtl/ripple_carry_adder.v rtl/adder_subtractor.v \
//       rtl/multiplier.v rtl/divider.v rtl/calculator_top.v
//   vvp sim_top
// =============================================================
`timescale 1ns/1ps

module tb_calculator_top;

    localparam WIDTH = 8;
    localparam OP_ADD = 2'b00, OP_SUB = 2'b01, OP_MUL = 2'b10, OP_DIV = 2'b11;

    reg               clk = 0;
    reg               rst_n;
    reg               start;
    reg  [1:0]        opcode;
    reg  [WIDTH-1:0]  a, b;
    wire [2*WIDTH-1:0] result;
    wire [WIDTH-1:0]   remainder;
    wire               busy, done, div_by_zero, overflow;

    integer errors = 0;

    calculator_top #(.WIDTH(WIDTH)) dut (
        .clk(clk), .rst_n(rst_n), .start(start), .opcode(opcode),
        .a(a), .b(b), .result(result), .remainder(remainder),
        .busy(busy), .done(done), .div_by_zero(div_by_zero), .overflow(overflow)
    );

    always #5 clk = ~clk;

    task run_op(input [1:0] op, input [WIDTH-1:0] av, input [WIDTH-1:0] bv);
        begin
            @(negedge clk);
            opcode = op; a = av; b = bv; start = 1'b1;
            @(negedge clk);
            start = 1'b0;
            wait (done == 1'b1);
            case (op)
                OP_ADD: check(result[WIDTH-1:0] === (av + bv), "ADD", av, bv, result);
                OP_SUB: check(result[WIDTH-1:0] === (av - bv), "SUB", av, bv, result);
                OP_MUL: check(result === (av * bv),            "MUL", av, bv, result);
                OP_DIV: begin
                    if (bv == 0)
                        check(div_by_zero === 1'b1, "DIV/0", av, bv, result);
                    else
                        check(result[WIDTH-1:0] === (av / bv) && remainder === (av % bv),
                              "DIV", av, bv, result);
                end
            endcase
            @(negedge clk);
        end
    endtask

    task check(input cond, input [8*8-1:0] name, input [WIDTH-1:0] av,
               input [WIDTH-1:0] bv, input [2*WIDTH-1:0] res);
        begin
            if (!cond) begin
                errors = errors + 1;
                $display("FAIL %0s: a=%0d b=%0d -> result=%0d remainder=%0d dbz=%b",
                          name, av, bv, res, remainder, div_by_zero);
            end
        end
    endtask

    integer k;

    initial begin
        rst_n = 0; start = 0; opcode = 0; a = 0; b = 0;
        repeat (3) @(negedge clk);
        rst_n = 1;

        $display("=== calculator_top full integration test ===");
        run_op(OP_ADD, 8'd10,  8'd20);
        run_op(OP_SUB, 8'd50,  8'd8);
        run_op(OP_SUB, 8'd8,   8'd50);   // underflow wraps
        run_op(OP_MUL, 8'd12,  8'd11);
        run_op(OP_DIV, 8'd100, 8'd9);
        run_op(OP_DIV, 8'd5,   8'd0);    // divide by zero

        for (k = 0; k < 60; k = k + 1) begin
            run_op(OP_ADD, $random, $random);
            run_op(OP_SUB, $random, $random);
            run_op(OP_MUL, $random, $random);
            run_op(OP_DIV, $random, ($random % 250) + 1);
        end

        if (errors == 0) $display("calculator_top: ALL PASS");
        else              $display("calculator_top: %0d FAILURES", errors);

        $finish;
    end

    initial begin
        $dumpfile("calculator_top.vcd");
        $dumpvars(0, tb_calculator_top);
    end

endmodule
