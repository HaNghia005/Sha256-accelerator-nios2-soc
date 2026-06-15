`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/29/2026 10:00:55 PM
// Design Name: 
// Module Name: tb_sha256_top
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

module tb_sha256_top;

reg clk;
reg reset_n;
reg        byte_valid;
reg        byte_last;
reg [7:0]  data_in;
wire       in_ready;
wire [255:0] digest;
wire         digest_valid;
wire         message_done;

integer file;
integer r;
reg [7:0] ch;
reg [7:0] prev_ch;
reg       prev_valid;
reg       first_byte;
integer char_val;

sha256_top dut (
    .clk(clk),
    .reset_n(reset_n),
    .byte_valid(byte_valid),
    .byte_last(byte_last),
    .data_in(data_in),
    .in_ready(in_ready),
    .digest(digest),
    .digest_valid(digest_valid),
    .message_done(message_done)
);

always #5 clk = ~clk;

// g?i 1 byte
task send_byte;
    input [7:0] data;
    input       last;
begin
    // Ch? module s?n sàng (b? @posedge clk d? th?a ? ??u)
    while (!in_ready) @(posedge clk);

    // Gán d? li?u v?i ?? tr? #1 ?? tránh race-condition t?i s??n lên c?a clk
    #1;
    byte_valid = 1'b1;
    data_in    = data;
    byte_last  = last;

    // ??i 1 chu k? ?? module l?y d? li?u
    @(posedge clk);
    
    // Không h? byte_valid ? ?ây ?? lu?ng data ???c b?m liên t?c
end
endtask

initial begin
    clk        = 0;
    reset_n    = 0;
    byte_valid = 0;
    byte_last  = 0;
    data_in    = 0;
    prev_valid = 0;
    first_byte = 1;

    #200;
    reset_n = 1;
    #10;

    file = $fopen("C:/Users/trongnghia/Desktop/input.txt", "rb");
    if (file == 0) begin
        $display("ERROR: Cannot open input.txt");
        $stop;
    end

   $write("Data doc tu file: "); 

    begin : read_loop
        while (1) begin
            char_val = $fgetc(file); // ??c t?ng ký t? m?t
            
            // N?u ??ng cu?i file (EOF = -1) thì thoát vòng l?p
            if (char_val == -1 || $feof(file)) 
                disable read_loop;

            ch = char_val[7:0]; 

            // B? qua CR (0x0D)
            if (ch == 8'h0D) begin
            end
            else begin
                $write("%c", ch); 

                if (!first_byte)
                    send_byte(prev_ch, 1'b0);

                prev_ch    = ch;
                prev_valid = 1'b1;
                first_byte = 1'b0;
            end
        end
    end
    $display("");
    
    $fclose(file);

    // X? lý byte cu?i cùng ho?c file r?ng
    if (prev_valid) begin
        send_byte(prev_ch, 1'b1);
        
        // Ch? kéo các tín hi?u xu?ng 0 sau khi toàn b? d? li?u ?ã ???c g?i xong
        #1;
        byte_valid = 1'b0;
        byte_last  = 1'b0;
        data_in    = 8'd0;
    end
    else begin
        $display("ERROR: File rong!");
        @(posedge clk);
        while (!in_ready) @(posedge clk);
    
        #1;
        byte_valid = 1'b0;
        byte_last  = 1'b1;
        data_in    = 8'd0;
    
        @(posedge clk);
    
        #1;
        byte_valid = 1'b0;
        byte_last  = 1'b0;
        data_in    = 8'd0;
    end

    wait(digest_valid);
    $display("====================================");
    $display("SHA256 = %h", digest);
    $display("====================================");

    #50;
    $stop;
end

endmodule