`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/29/2026 02:17:26 PM
// Design Name: 
// Module Name: sha256_top
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
module sha256_top(
    input wire clk,
    input wire reset_n,
    input wire        byte_valid,
    input wire        byte_last,
    input wire [7:0]  data_in,
    output wire       in_ready,
    output wire [255:0] digest,
    output wire         digest_valid,
    output wire         message_done
);

// Controller <-> Core signals
wire [511:0] block_out;
wire         block_valid;
wire         block_last;
wire         ctrl_done;

// Core control
wire core_ready;
wire [255:0] core_digest;
wire         core_digest_valid;
reg  core_init;
reg  core_next;
reg  first_block;

// Handshake: gi? block cho ??n khi core_ready
reg  [511:0] block_latch;
reg          block_pending;
reg          block_last_latch;
wire block_ready_to_ctrl;
assign block_ready_to_ctrl = ~block_pending;

wire accept_block;
assign accept_block = block_pending && core_ready;
reg final_block_in_core;
wire final_digest_valid;
assign final_digest_valid = core_digest_valid && final_block_in_core;

// Instantiate MESSAGE CONTROLLER
sha_message_controller u_ctrl (
    .clk        (clk),
    .reset      (reset_n),
    .byte_valid (byte_valid),
    .byte_last  (byte_last),
    .data_in    (data_in),
    .in_ready   (in_ready),
    .block_ready (block_ready_to_ctrl),
    .block_valid(block_valid),
    .block_last (block_last),
    .block_out  (block_out),
    .message_done(ctrl_done)
);

// Latch block khi controller phát, gi? ??n khi core s?n sàng
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        block_pending    <= 1'b0;
        block_latch      <= 512'd0;
        block_last_latch <= 1'b0;
    end
    else begin
        if (block_valid) begin
            block_latch      <= block_out;
            block_last_latch <= block_last;
            block_pending    <= 1'b1;
        end
        else if (block_pending && core_ready) begin
            block_pending <= 1'b0;
        end
    end
end

// first_block: reset khi message_done
always @(posedge clk or negedge reset_n) begin
    if (!reset_n)
        first_block <= 1'b1;
    else if (final_digest_valid)
        first_block <= 1'b1;
    else if (accept_block)
        first_block <= 1'b0;
end

always @(posedge clk or negedge reset_n) begin
    if (!reset_n)
        final_block_in_core <= 1'b0;
    else if (final_digest_valid)
        final_block_in_core <= 1'b0;
    else if (accept_block)
        final_block_in_core <= block_last_latch;
end

// INIT / NEXT control logic
always @(*) begin
    core_init = 1'b0;
    core_next = 1'b0;
    if (block_pending && core_ready) begin
        if (first_block)
            core_init = 1'b1;
        else
            core_next = 1'b1;
    end
end

// Instantiate SHA256 CORE
sha_core u_core (
    .clk         (clk),
    .reset_n     (reset_n),
    .init        (core_init),
    .next        (core_next),
    .mode        (1'b1),
    .block       (block_latch),   
    .ready       (core_ready),
    .digest      (core_digest),
    .digest_valid(core_digest_valid)
);

// Message done
assign digest       = core_digest;
assign digest_valid = final_digest_valid;
assign message_done = final_digest_valid;

endmodule
