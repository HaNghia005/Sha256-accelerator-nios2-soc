`timescale 1ns / 1ps
`default_nettype none

module sha_core(
    input wire            clk,
    input wire            reset_n,
    input wire            init,
    input wire            next,
    input wire            mode,
    input wire [511 : 0]  block,
    output reg            ready,
    output wire [255 : 0] digest,
    output reg            digest_valid
);

    localparam SHA256_H0_0 = 32'h6a09e667;
    localparam SHA256_H0_1 = 32'hbb67ae85;
    localparam SHA256_H0_2 = 32'h3c6ef372;
    localparam SHA256_H0_3 = 32'ha54ff53a;
    localparam SHA256_H0_4 = 32'h510e527f;
    localparam SHA256_H0_5 = 32'h9b05688c;
    localparam SHA256_H0_6 = 32'h1f83d9ab;
    localparam SHA256_H0_7 = 32'h5be0cd19;

    localparam IDLE         = 2'd0;
    localparam CALC_WK      = 2'd1;
    localparam CALC_ROUNDS  = 2'd2;
    localparam DONE         = 2'd3;

    reg [1:0] state;
    reg [6:0] round_ctr; // Dùng 7 bit có the dem toi 64

    reg [31:0] a_reg, b_reg, c_reg, d_reg, e_reg, f_reg, g_reg, h_reg;
    reg [31:0] H0, H1, H2, H3, H4, H5, H6, H7;

    wire [31:0] w0, w1;
    wire [31:0] k0, k1;

    reg [31:0] wk0_reg, wk1_reg;
    
    wire [31:0] a_mid, b_mid, c_mid, d_mid, e_mid, f_mid, g_mid, h_mid;
    wire [31:0] a_next, b_next, c_next, d_next, e_next, f_next, g_next, h_next;

    //  Cap tín hieu Init và Shift liên tuc cho sha256_mem
    wire mem_init = (state == IDLE) && (init || next);
    wire mem_next = (state == CALC_WK) || (state == CALC_ROUNDS);

    sha256_mem u_mem(
        .clk(clk),
        .reset_n(reset_n),
        .block(block),
        .round(round_ctr[5:0]), 
        .init(mem_init),
        .next(mem_next),
        .W0(w0),
        .W1(w1)
    );

    sha256_constants_k u_k(
        .round(round_ctr[5:0]),
        .K0(k0),
        .K1(k1)
    );

    sha256_round_comb u_round0 (
        .a(a_reg), .b(b_reg), .c(c_reg), .d(d_reg),
        .e(e_reg), .f(f_reg), .g(g_reg), .h(h_reg),
        .wk(wk0_reg), 
        .a_next(a_mid), .b_next(b_mid), .c_next(c_mid), .d_next(d_mid),
        .e_next(e_mid), .f_next(f_mid), .g_next(g_mid), .h_next(h_mid)
    );

    sha256_round_comb u_round1 (
        .a(a_mid), .b(b_mid), .c(c_mid), .d(d_mid),
        .e(e_mid), .f(f_mid), .g(g_mid), .h(h_mid),
        .wk(wk1_reg), 
        .a_next(a_next), .b_next(b_next), .c_next(c_next), .d_next(d_next),
        .e_next(e_next), .f_next(f_next), .g_next(g_next), .h_next(h_next)
    );

    assign digest = {H0, H1, H2, H3, H4, H5, H6, H7};

    // Controller Pipelined State Machine
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            ready <= 1'b1;
            digest_valid <= 1'b0;
            round_ctr <= 7'd0;
            
            H0 <= SHA256_H0_0; H1 <= SHA256_H0_1; H2 <= SHA256_H0_2; H3 <= SHA256_H0_3;
            H4 <= SHA256_H0_4; H5 <= SHA256_H0_5; H6 <= SHA256_H0_6; H7 <= SHA256_H0_7;
            
            a_reg <= 32'd0; b_reg <= 32'd0; c_reg <= 32'd0; d_reg <= 32'd0;
            e_reg <= 32'd0; f_reg <= 32'd0; g_reg <= 32'd0; h_reg <= 32'd0;
            
            wk0_reg <= 32'd0; wk1_reg <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    digest_valid <= 1'b0;
                    if (init || next) begin
                        ready <= 1'b0;
                        round_ctr <= 7'd0;
                        state <= CALC_WK; 
                        
                        if (init) begin
                            a_reg <= SHA256_H0_0; b_reg <= SHA256_H0_1;
                            c_reg <= SHA256_H0_2; d_reg <= SHA256_H0_3;
                            e_reg <= SHA256_H0_4; f_reg <= SHA256_H0_5;
                            g_reg <= SHA256_H0_6; h_reg <= SHA256_H0_7;
                        end else begin
                            a_reg <= H0; b_reg <= H1; c_reg <= H2; d_reg <= H3;
                            e_reg <= H4; f_reg <= H5; g_reg <= H6; h_reg <= H7;
                        end
                    end else begin
                        ready <= 1'b1;
                    end
                end

                CALC_WK: begin
                    // Stage 1 - Nap WK cho 2 vòng dau tiên (round 0, 1)
                    wk0_reg <= w0 + k0;
                    wk1_reg <= w1 + k1;
                    
                    // Look-ahead bien dem vòng sau lay data cua round 2, 3
                    round_ctr <= 7'd2;
                    state <= CALC_ROUNDS;
                end

                CALC_ROUNDS: begin
                    // Stage 2: Cap nhat Output cua khoi logic b?m vào thanh ghi State
                    a_reg <= a_next; b_reg <= b_next; c_reg <= c_next; d_reg <= d_next;
                    e_reg <= e_next; f_reg <= f_next; g_reg <= g_next; h_reg <= h_next;

                    // Dong thoi, Stage 1 lai tiep tuc tính W+K cho vòng ke tiep
                    wk0_reg <= w0 + k0;
                    wk1_reg <= w1 + k1;
               
                    // tính ket qua cho W62 và K62 dã bi tre 1 nhip do pipeline.
                    if (round_ctr == 7'd64) begin
                        state <= DONE;
                    end else begin
                        round_ctr <= round_ctr + 7'd2;
                    end
                end

                DONE: begin
                    H0 <= H0 + a_reg; H1 <= H1 + b_reg;
                    H2 <= H2 + c_reg; H3 <= H3 + d_reg;
                    H4 <= H4 + e_reg; H5 <= H5 + f_reg;
                    H6 <= H6 + g_reg; H7 <= H7 + h_reg;

                    digest_valid <= 1'b1;
                    ready <= 1'b0;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
`default_nettype wire