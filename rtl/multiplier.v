// =============================================================
// multiplier.v
// Unsigned WIDTH x WIDTH -> 2*WIDTH sequential shift-add multiplier
// (the classic "add-and-shift-right" algorithm). Takes WIDTH clock
// cycles. Reuses ripple_carry_adder as its only arithmetic element.
//
// Internal register P is (2*WIDTH+1) bits, laid out as:
//   P[2W]        : guard bit  (catches carry-out of the partial add)
//   P[2W-1:W]    : accumulator (partial product, high half)
//   P[W-1:0]     : multiplier bits still to be consumed / low half
//                  of the final product as they get shifted in
//
// Each of WIDTH cycles:
//   if P[0]==1: {guard,acc} <= acc + M      (add multiplicand)
//   else:       {guard,acc} <= {1'b0, acc}  (no add)
//   then shift the whole (guard,acc,low) register right by 1,
//   with a 0 shifted into the new MSB.
// After exactly WIDTH cycles, P[2W-1:0] holds the final 2*WIDTH
// product directly (the guard bit re-zeros itself every cycle it
// isn't used, so no separate "latch" step is needed).
// =============================================================
`timescale 1ns/1ps

module multiplier #(
    parameter WIDTH = 8
) (
    input  wire               clk,
    input  wire               rst_n,
    input  wire                start,
    input  wire [WIDTH-1:0]    multiplicand,
    input  wire [WIDTH-1:0]    multiplier_in,
    output wire [2*WIDTH-1:0]  product,
    output reg                 busy,
    output reg                 done
);

    localparam PW = 2*WIDTH; // index of the guard bit within P

    reg  [PW:0]              P;     // guard(1) + acc(WIDTH) + low(WIDTH)
    reg  [WIDTH-1:0]         M;
    reg  [$clog2(WIDTH+1):0] count;

    // Combinational adder: current accumulator + multiplicand
    wire [WIDTH-1:0] add_sum;
    wire             add_cout;

    ripple_carry_adder #(.WIDTH(WIDTH)) mult_adder (
        .a    (P[PW-1:WIDTH]),
        .b    (M),
        .cin  (1'b0),
        .sum  (add_sum),
        .cout (add_cout)
    );

    wire             eff_guard = P[0] ? add_cout : 1'b0;
    wire [WIDTH-1:0] eff_acc   = P[0] ? add_sum  : P[PW-1:WIDTH];

    assign product = P[PW-1:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            P     <= {(PW+1){1'b0}};
            M     <= {WIDTH{1'b0}};
            count <= 0;
            busy  <= 1'b0;
            done  <= 1'b0;
        end else if (start && !busy) begin
            P     <= {1'b0, {WIDTH{1'b0}}, multiplier_in}; // guard=0, acc=0, low=multiplier
            M     <= multiplicand;
            count <= 0;
            busy  <= 1'b1;
            done  <= 1'b0;
        end else if (busy) begin
            P <= {1'b0, eff_guard, eff_acc, P[WIDTH-1:1]};
            if (count == WIDTH-1) begin
                busy <= 1'b0;
                done <= 1'b1;
            end
            count <= count + 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule
