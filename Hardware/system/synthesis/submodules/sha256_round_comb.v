`timescale 1ns / 1ps
`default_nettype none

module sha256_round_comb(
    input wire [31:0] a,
    input wire [31:0] b,
    input wire [31:0] c,
    input wire [31:0] d,
    input wire [31:0] e,
    input wire [31:0] f,
    input wire [31:0] g,
    input wire [31:0] h,
    input wire [31:0] wk,  // Nhan truc tiep (W_i + K_i) tu thanh ghi Pipeline
    
    output wire [31:0] a_next,
    output wire [31:0] b_next,
    output wire [31:0] c_next,
    output wire [31:0] d_next,
    output wire [31:0] e_next,
    output wire [31:0] f_next,
    output wire [31:0] g_next,
    output wire [31:0] h_next    
);
    
    wire [31:0] sum0;
    wire [31:0] sum1;
    wire [31:0] ch;
    wire [31:0] maj;
    wire [31:0] t1;
    wire [31:0] t2;

    // Sigma 0 và Sigma 1 (RotRight & Shift)
    assign sum0 = {a[1:0], a[31:2]} ^ {a[12:0], a[31:13]} ^ {a[21:0], a[31:22]};
    assign sum1 = {e[5:0], e[31:6]} ^ {e[10:0], e[31:11]} ^ {e[24:0], e[31:25]};
    
    // Hàm Ch và Maj
    assign ch  = (e & f) ^ (~e & g);
    assign maj = (a & b) ^ (a & c) ^ (b & c);

    // Tính T1 và T2 - Luu ý wk dã duocc cong san W và K tu truoc
    assign t1 = h + sum1 + ch + wk;
    assign t2 = sum0 + maj;

    // Cap nhat State cho vòng tiep theo
    assign h_next = g;
    assign g_next = f;
    assign f_next = e;
    assign e_next = d + t1;
    assign d_next = c;
    assign c_next = b;
    assign b_next = a;
    assign a_next = t1 + t2;

endmodule
`default_nettype wire