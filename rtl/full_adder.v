// =============================================================
// full_adder.v
// 1-bit full adder, described at gate/logic-equation level so it
// maps directly and predictably onto standard cells during
// synthesis (XOR2, AND2, AND2, OR2 -> tools/ABC will typically
// pack this into a single FA standard cell, e.g. sky130_fd_sc_hd__fa_1).
// =============================================================
`timescale 1ns/1ps

module full_adder (
    input  wire a,
    input  wire b,
    input  wire cin,
    output wire sum,
    output wire cout
);

    assign sum  = a ^ b ^ cin;
    assign cout = (a & b) | (b & cin) | (a & cin);

endmodule
