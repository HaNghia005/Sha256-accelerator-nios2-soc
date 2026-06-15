`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/09/2026 01:42:20 PM
// Design Name: 
// Module Name: sha_message_controller
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


module sha_message_controller(
    input wire clk,
    input wire reset,
    input wire byte_valid,
    input wire byte_last,
    input wire [7:0] data_in,
    input wire block_ready,
    
    output wire in_ready,
    output reg block_valid,
    output reg block_last,
    output reg [511:0] block_out,
    output reg message_done
    //output reg hash_start
    );
    localparam STATE_RECEIVE=3'd0;
    localparam STATE_EMIT_FULL=3'd1;
    localparam STATE_EMIT_LAST1=3'd2;
    localparam STATE_EMIT_LASTA=3'd3;
    localparam STATE_EMIT_LASTB=3'd4;
    localparam STATE_EMIT_PAD=3'd5;
    
    reg [2:0] state;
    reg pad_after_full;
    reg [511:0] block_buffer;
    //reg [7:0] buffer [0:63];
    reg [6:0] byte_count;
    wire [5:0] idx;
    reg [63:0] total_bytes;
    //reg [511:0] block_temp;
    //reg pad_after_full;
    wire [63:0] message_bits;
    //integer i,j;
    
    assign in_ready = (state == STATE_RECEIVE);
    assign message_bits = total_bytes << 3;
    assign idx = byte_count[5:0];
    always@(posedge clk)
    begin
        if(!reset)
        begin
            block_valid<=1'b0;
            block_last<=1'b0;
            message_done<=1'b0;
            block_out<=512'd0;
            
            state<=STATE_RECEIVE;
            pad_after_full<=1'b0;
            block_buffer   <= 512'd0;
            
            byte_count<=7'd0;
            total_bytes<=64'd0;
            //block_temp<=512'd0;
            //message_bits<=64'd0;
        end
        else
        begin
            block_valid<=1'b0;
            block_last<=1'b0;
            message_done<=1'b0;
            
            case(state)
                STATE_RECEIVE:
                begin
                    if(byte_valid)
                    begin
                        block_buffer[511-(idx<<3)-:8]<=data_in;
                        total_bytes<=total_bytes+64'd1;
                        
                        if(byte_count==7'd63) 
                        begin
                            byte_count<=7'd64;
                            state<=STATE_EMIT_FULL;
                            if(byte_last)
                                pad_after_full<=1'b1;
                            else
                                pad_after_full<=1'b0;
                        end
                        else
                        begin
                            byte_count<=byte_count+1;
                            if(byte_last)
                            begin
                                if(byte_count<=7'd54) state<=STATE_EMIT_LAST1;
                                else state<=STATE_EMIT_LASTA;
                            end
                        end
                    end
                    else if(byte_last)//message rong
                    begin
                        if(byte_count<=7'd55)
                            state<=STATE_EMIT_LAST1;
                        else 
                            state<=STATE_EMIT_LASTA;
                    end
                end
                STATE_EMIT_FULL:
                begin
                    if(block_ready)
                    begin

                        block_out <=block_buffer;
                        block_valid<=1'b1;
                        block_last<=1'b0;
                        byte_count<=7'd0;
                        
                        block_buffer<=512'd0;
                        if(pad_after_full)
                        begin
                            state <= STATE_EMIT_PAD;
                            pad_after_full<=1'b0;
                        end
                        else state<= STATE_RECEIVE;
                    end
                end
                STATE_EMIT_LAST1:
                begin
                    if(block_ready)
                    begin
                        block_out<=block_buffer;
                        
                        block_out[511-(idx<<3)-:8]<=8'h80;                         
                       
                        block_out[63:0]<=message_bits;
                        block_valid<= 1'b1;
                        block_last<= 1'b1;
                        message_done<= 1'b1;
                        
                        state<=STATE_RECEIVE;
                        byte_count<=7'd0;
                        total_bytes<=64'd0;
                        block_buffer<=512'd0;
                    end  
                end
                STATE_EMIT_LASTA:
                begin
                    if(block_ready)
                    begin
                        block_out<=block_buffer;
                
                        block_out[511-(idx<<3)-:8] <= 8'h80;
                        block_valid<= 1'b1;
                        block_last<= 1'b0;
                        
                        state<=STATE_EMIT_LASTB;
                        byte_count<=7'd0;
                        block_buffer<=512'd0;
                    end
                    
                end
                STATE_EMIT_LASTB:
                begin
                    if(block_ready)
                    begin
                        
                        block_out<={448'd0,message_bits};
                        block_valid<= 1'b1;
                        block_last<= 1'b1;
                        message_done<= 1'b1;
                        
                        state<=STATE_RECEIVE;
                        byte_count<=7'd0;
                        total_bytes<=64'd0;
                        block_buffer<=512'd0;
                    end
                    
                end
                STATE_EMIT_PAD:
                begin
                    if(block_ready)
                    begin
                        block_out<={8'h80,440'd0,message_bits};
                        
                        block_valid<= 1'b1;
                        block_last<= 1'b1;
                        message_done<= 1'b1;
                        
                        state<=STATE_RECEIVE;
                        byte_count<=7'd0;
                        total_bytes<=64'd0;
                        block_buffer<=512'd0;
                    end
                    
                end
                default: 
                begin
                    state<=STATE_RECEIVE;
                end
            endcase
        end
    end
endmodule
