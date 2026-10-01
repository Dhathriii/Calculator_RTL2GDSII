// =============================================================
// ripple_carry_adder.v
// Structural N-bit ripple-carry adder, built by instantiating
// WIDTH copies of full_adder and chaining the carry. This is the
// arithmetic core reused by the subtractor, multiplier and divider
// below, so the whole calculator ultimately bottoms out on one
// verified adder cell.
// =============================================================
`timescale 1ns/1ps

module ripple_carry_adder #(
    parameter WIDTH = 8
) (
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    input  wire             cin,
    output wire [WIDTH-1:0] sum,
    output wire             cout
);

    wire [WIDTH:0] carry;
    assign carry[0] = cin;
    assign cout     = carry[WIDTH];

    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : fa_stage
            full_adder fa_inst (
                .a    (a[i]),
                .b    (b[i]),
                .cin  (carry[i]),
                .sum  (sum[i]),
                .cout (carry[i+1])
            );
        end
    endgenerate

endmodule
