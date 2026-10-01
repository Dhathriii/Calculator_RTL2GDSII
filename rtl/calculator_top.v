// =============================================================
// calculator_top.v
// Top-level 4-function calculator.
//   opcode: 2'b00 = ADD   (a + b)                 - 1 cycle
//           2'b01 = SUB   (a - b)                 - 1 cycle
//           2'b10 = MUL   (a * b)                 - WIDTH cycles
//           2'b11 = DIV   (a / b, a % b)           - WIDTH cycles
//
// Protocol: assert 'start' for one cycle with opcode/a/b valid.
// 'busy' is high while a multi-cycle op runs. 'done' pulses for
// one cycle when 'result'/'remainder' are valid. add/sub finish
// combinationally and pulse done the same cycle start is seen.
// =============================================================
`timescale 1ns/1ps

module calculator_top #(
    parameter WIDTH = 8
) (
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  start,
    input  wire [1:0]            opcode,
    input  wire [WIDTH-1:0]      a,
    input  wire [WIDTH-1:0]      b,

    output reg  [2*WIDTH-1:0]    result,      // add/sub: zero-extended into low half
                                               // mul: full 2*WIDTH product
                                               // div: quotient in low half
    output reg  [WIDTH-1:0]      remainder,   // valid for DIV only
    output reg                   busy,
    output reg                   done,
    output reg                   div_by_zero,
    output reg                   overflow
);

    localparam OP_ADD = 2'b00;
    localparam OP_SUB = 2'b01;
    localparam OP_MUL = 2'b10;
    localparam OP_DIV = 2'b11;

    // ---- combinational add/sub -------------------------------------------------
    wire [WIDTH-1:0] addsub_result;
    wire             addsub_cout;
    wire             addsub_overflow;

    adder_subtractor #(.WIDTH(WIDTH)) u_addsub (
        .a        (a),
        .b        (b),
        .sub      (opcode[0]),      // opcode==OP_SUB (01) -> sub=1
        .result   (addsub_result),
        .cout     (addsub_cout),
        .overflow (addsub_overflow)
    );

    // ---- sequential multiplier --------------------------------------------------
    wire [2*WIDTH-1:0] mul_product;
    wire               mul_busy, mul_done;
    reg                mul_start;

    multiplier #(.WIDTH(WIDTH)) u_mul (
        .clk           (clk),
        .rst_n         (rst_n),
        .start         (mul_start),
        .multiplicand  (a),
        .multiplier_in (b),
        .product       (mul_product),
        .busy          (mul_busy),
        .done          (mul_done)
    );

    // ---- sequential divider ------------------------------------------------------
    wire [WIDTH-1:0] div_quotient, div_remainder;
    wire             div_busy, div_done, div_dbz;
    reg              div_start;

    divider #(.WIDTH(WIDTH)) u_div (
        .clk          (clk),
        .rst_n        (rst_n),
        .start        (div_start),
        .dividend     (a),
        .divisor      (b),
        .quotient     (div_quotient),
        .remainder    (div_remainder),
        .busy         (div_busy),
        .done         (div_done),
        .div_by_zero  (div_dbz)
    );

    // ---- control FSM ---------------------------------------------------------
    localparam S_IDLE = 2'b00,
               S_MUL   = 2'b01,
               S_DIV   = 2'b10;

    reg [1:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S_IDLE;
            mul_start   <= 1'b0;
            div_start   <= 1'b0;
            result      <= {2*WIDTH{1'b0}};
            remainder   <= {WIDTH{1'b0}};
            busy        <= 1'b0;
            done        <= 1'b0;
            div_by_zero <= 1'b0;
            overflow    <= 1'b0;
        end else begin
            // default: pulses de-assert unless re-driven below
            mul_start <= 1'b0;
            div_start <= 1'b0;
            done      <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (start) begin
                        case (opcode)
                            OP_ADD, OP_SUB: begin
                                result      <= { {WIDTH{1'b0}}, addsub_result };
                                overflow    <= addsub_overflow;
                                div_by_zero <= 1'b0;
                                busy        <= 1'b0;
                                done        <= 1'b1;   // single-cycle result
                            end
                            OP_MUL: begin
                                mul_start   <= 1'b1;
                                busy        <= 1'b1;
                                div_by_zero <= 1'b0;
                                overflow    <= 1'b0;
                                state       <= S_MUL;
                            end
                            OP_DIV: begin
                                div_start   <= 1'b1;
                                busy        <= 1'b1;
                                overflow    <= 1'b0;
                                state       <= S_DIV;
                            end
                        endcase
                    end
                end

                S_MUL: begin
                    busy <= mul_busy;
                    if (mul_done) begin
                        result <= mul_product;
                        done   <= 1'b1;
                        busy   <= 1'b0;
                        state  <= S_IDLE;
                    end
                end

                S_DIV: begin
                    busy <= div_busy;
                    if (div_done) begin
                        result      <= { {WIDTH{1'b0}}, div_quotient };
                        remainder   <= div_remainder;
                        div_by_zero <= div_dbz;
                        done        <= 1'b1;
                        busy        <= 1'b0;
                        state       <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
