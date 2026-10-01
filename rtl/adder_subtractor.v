// =============================================================
// adder_subtractor.v
// N-bit add/subtract unit. Subtraction is done as two's-complement
// addition: a - b = a + (~b) + 1. The 'sub' control bit both
// inverts b (via XOR) and feeds cin, so add and subtract share the
// exact same ripple_carry_adder hardware - no separate subtractor
// datapath is needed.
//   sub = 0 -> result = a + b
//   sub = 1 -> result = a - b
// 'cout' for sub=1 is the *no-borrow* flag: cout=1 means a >= b
// (unsigned), cout=0 means a < b (borrow occurred). The divider
// below relies on exactly this convention.
// =============================================================
`timescale 1ns/1ps

module adder_subtractor #(
    parameter WIDTH = 8
) (
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    input  wire             sub,       // 0 = add, 1 = subtract (a - b)
    output wire [WIDTH-1:0] result,
    output wire             cout,      // add: carry-out. sub: no-borrow flag
    output wire             overflow   // signed overflow flag
);

    wire [WIDTH-1:0] b_muxed = b ^ {WIDTH{sub}};

    ripple_carry_adder #(.WIDTH(WIDTH)) rca_inst (
        .a    (a),
        .b    (b_muxed),
        .cin  (sub),
        .sum  (result),
        .cout (cout)
    );

    // Signed overflow: operands (as adjusted) share a sign bit,
    // but the result's sign bit differs from theirs.
    assign overflow = (a[WIDTH-1] == b_muxed[WIDTH-1]) &&
                       (result[WIDTH-1] != a[WIDTH-1]);

endmodule
