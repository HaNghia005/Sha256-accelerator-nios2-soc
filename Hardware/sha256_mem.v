`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/29/2026 02:20:42 PM
// Design Name: 
// Module Name: sha256_mem
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


`default_nettype none

module sha256_mem(
    input wire         clk,
    input wire         reset_n,
    input wire [511:0] block,
    input wire [5:0]   round,
    input wire         init,
    input wire         next,
    output reg [31:0] W0,
    output reg [31:0] W1
);

    
    reg [31:0] w_mem0, w_mem1, w_mem2, w_mem3;
    reg [31:0] w_mem4, w_mem5, w_mem6, w_mem7;
    reg [31:0] w_mem8, w_mem9, w_mem10, w_mem11;
    reg [31:0] w_mem12, w_mem13, w_mem14, w_mem15;

    wire [31:0] sigma0_w1;
    wire [31:0] sigma0_w2;
    wire [31:0] sigma1_w14;
    wire [31:0] sigma1_w15;
    
    wire [31:0] W_new0;
    wire [31:0] W_new1;
    
    assign sigma0_w1={w_mem1[6:0],w_mem1[31:7]}^{w_mem1[17:0],w_mem1[31:18]}^{3'b0,w_mem1[31:3]};
    assign sigma0_w2={w_mem2[6:0],w_mem2[31:7]}^{w_mem2[17:0],w_mem2[31:18]}^{3'b0,w_mem2[31:3]};
    assign sigma1_w14={w_mem14[16:0],w_mem14[31:17]}^{w_mem14[18:0],w_mem14[31:19]}^{10'b0,w_mem14[31:10]};
    assign sigma1_w15={w_mem15[16:0],w_mem15[31:17]}^{w_mem15[18:0],w_mem15[31:19]}^{10'b0,w_mem15[31:10]};
    
    assign W_new0 = w_mem0+sigma0_w1+w_mem9+sigma1_w14;
    assign W_new1 = w_mem1+sigma0_w2+w_mem10+sigma1_w15;
    always@(*)
    begin
        if(round< 6'd16)
        begin
            case(round[3:0])
                4'd0:  begin W0 = w_mem0;  W1 = w_mem1;  end
                4'd1:  begin W0 = w_mem1;  W1 = w_mem2;  end
                4'd2:  begin W0 = w_mem2;  W1 = w_mem3;  end
                4'd3:  begin W0 = w_mem3;  W1 = w_mem4;  end
                4'd4:  begin W0 = w_mem4;  W1 = w_mem5;  end
                4'd5:  begin W0 = w_mem5;  W1 = w_mem6;  end
                4'd6:  begin W0 = w_mem6;  W1 = w_mem7;  end
                4'd7:  begin W0 = w_mem7;  W1 = w_mem8;  end
                4'd8:  begin W0 = w_mem8;  W1 = w_mem9;  end
                4'd9:  begin W0 = w_mem9;  W1 = w_mem10; end
                4'd10: begin W0 = w_mem10; W1 = w_mem11; end
                4'd11: begin W0 = w_mem11; W1 = w_mem12; end
                4'd12: begin W0 = w_mem12; W1 = w_mem13; end
                4'd13: begin W0 = w_mem13; W1 = w_mem14; end
                4'd14: begin W0 = w_mem14; W1 = w_mem15; end

                4'd15: begin W0 = w_mem15; W1 = W_new0; end

                default: begin W0 = 32'h0; W1 = 32'h0; end
            endcase
        end
        else 
        begin
            W0 = W_new0;
            W1 = W_new1;
        end
    end
    
    
    
    always@(posedge clk or negedge reset_n)
    begin
        if(!reset_n)
        begin
            w_mem0  <= 32'h0;
            w_mem1  <= 32'h0;
            w_mem2  <= 32'h0;
            w_mem3  <= 32'h0;
            w_mem4  <= 32'h0;
            w_mem5  <= 32'h0;
            w_mem6  <= 32'h0;
            w_mem7  <= 32'h0;
            w_mem8  <= 32'h0;
            w_mem9  <= 32'h0;
            w_mem10 <= 32'h0;
            w_mem11 <= 32'h0;
            w_mem12 <= 32'h0;
            w_mem13 <= 32'h0;
            w_mem14 <= 32'h0;
            w_mem15 <= 32'h0;
        end
        else 
        begin
            if(init) 
            begin
                w_mem0  <= block[511:480];
                w_mem1  <= block[479:448];
                w_mem2  <= block[447:416];
                w_mem3  <= block[415:384];
                w_mem4  <= block[383:352];
                w_mem5  <= block[351:320];
                w_mem6  <= block[319:288];
                w_mem7  <= block[287:256];
                w_mem8  <= block[255:224];
                w_mem9  <= block[223:192];
                w_mem10 <= block[191:160];
                w_mem11 <= block[159:128];
                w_mem12 <= block[127:96];
                w_mem13 <= block[95:64];
                w_mem14 <= block[63:32];
                w_mem15 <= block[31:0];
            end
            else if(next && (round>=6'd16))
            begin
                w_mem0  <= w_mem2;
                w_mem1  <= w_mem3;
                w_mem2  <= w_mem4;
                w_mem3  <= w_mem5;
                w_mem4  <= w_mem6;
                w_mem5  <= w_mem7;
                w_mem6  <= w_mem8;
                w_mem7  <= w_mem9;
                w_mem8  <= w_mem10;
                w_mem9  <= w_mem11;
                w_mem10 <= w_mem12;
                w_mem11 <= w_mem13;
                w_mem12 <= w_mem14;
                w_mem13 <= w_mem15;
                w_mem14 <= W_new0;
                w_mem15 <= W_new1;
            end
        end
    end
endmodule