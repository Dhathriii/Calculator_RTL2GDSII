// =============================================================
// divider.v
// Unsigned WIDTH-bit restoring divider: dividend / divisor ->
// quotient, remainder. Takes WIDTH clock cycles. Reuses
// adder_subtractor (in subtract mode) as its only arithmetic
// element; cout from that module is used directly as the
// "no-borrow" flag (cout=1 <=> A_shifted >= divisor).
//
// Registers:
//   A (remainder, WIDTH bits), Q (quotient, WIDTH bits, starts
//   out holding the dividend and is shifted/filled in bit by bit),
//   M (divisor, WIDTH bits).
//
// Each cycle:
//   1. shift {A,Q} left by 1 (dividend's next MSB flows into A)
//   2. trial subtract: A_shifted - M
//   3. if no borrow: A <= result, Q[0] <= 1
//      else (borrow): A <= A_shifted (restore, discard subtraction),
//                      Q[0] <= 0
// =============================================================
`timescale 1ns/1ps

module divider #(
    parameter WIDTH = 8
) (
    input  wire               clk,
    input  wire                rst_n,
    input  wire                start,
    input  wire [WIDTH-1:0]    dividend,
    input  wire [WIDTH-1:0]    divisor,
    output reg  [WIDTH-1:0]    quotient,
    output reg  [WIDTH-1:0]    remainder,
    output reg                 busy,
    output reg                 done,
    output reg                 div_by_zero
);

    reg  [WIDTH-1:0]         A;      // remainder register
    reg  [WIDTH-1:0]         Q;      // quotient / shifting dividend register
    reg  [WIDTH-1:0]         M;      // divisor register
    reg  [$clog2(WIDTH+1):0] count;

    // Shift {A,Q} left by one bit before the trial subtraction
    wire [WIDTH-1:0] A_shifted = {A[WIDTH-2:0], Q[WIDTH-1]};
    wire [WIDTH-1:0] Q_shifted = {Q[WIDTH-2:0], 1'b0};

    wire [WIDTH-1:0] sub_result;
    wire             no_borrow;

    adder_subtractor #(.WIDTH(WIDTH)) div_sub (
        .a        (A_shifted),
        .b        (M),
        .sub      (1'b1),
        .result   (sub_result),
        .cout     (no_borrow),   // 1 = A_shifted >= M (no borrow)
        .overflow ()             // unused, unsigned division
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            A            <= {WIDTH{1'b0}};
            Q            <= {WIDTH{1'b0}};
            M            <= {WIDTH{1'b0}};
            count        <= 0;
            busy         <= 1'b0;
            done         <= 1'b0;
            div_by_zero  <= 1'b0;
            quotient     <= {WIDTH{1'b0}};
            remainder    <= {WIDTH{1'b0}};
        end else if (start && !busy) begin
            if (divisor == {WIDTH{1'b0}}) begin
                // Divide by zero: flag it, finish immediately, no valid result
                div_by_zero <= 1'b1;
                done        <= 1'b1;
                busy        <= 1'b0;
                quotient    <= {WIDTH{1'b1}}; // conventional "invalid" pattern
                remainder   <= dividend;
            end else begin
                A           <= {WIDTH{1'b0}};
                Q           <= dividend;
                M           <= divisor;
                count       <= 0;
                busy        <= 1'b1;
                done        <= 1'b0;
                div_by_zero <= 1'b0;
            end
        end else if (busy) begin
            if (no_borrow) begin
                A <= sub_result;
                Q <= {Q_shifted[WIDTH-1:1], 1'b1};
            end else begin
                A <= A_shifted;
                Q <= {Q_shifted[WIDTH-1:1], 1'b0};
            end

            if (count == WIDTH-1) begin
                busy      <= 1'b0;
                done      <= 1'b1;
                // On the final cycle, latch the *just computed* next
                // values directly into the outputs so done/outputs
                // update on the same edge.
                quotient  <= no_borrow ? {Q_shifted[WIDTH-1:1], 1'b1} : {Q_shifted[WIDTH-1:1], 1'b0};
                remainder <= no_borrow ? sub_result : A_shifted;
            end
            count <= count + 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule
