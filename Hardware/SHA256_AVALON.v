`timescale 1ns / 1ps
`default_nettype none

module SHA256_AVALON (
    input wire clk,
    input wire reset_n,

    input wire [4:0]  address,    // 5 bit để chứa địa chỉ từ 0 đến 24
    input wire        write,
    input wire        read,
    input wire [31:0] writedata,

    output reg [31:0] readdata
);


reg [511:0] block_reg;   // Thanh ghi chứa khối 512-bit

reg init_reg;
reg next_reg;
reg done_reg;

wire [255:0] digest;
wire digest_valid;
wire ready;


always @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
        init_reg <= 1'b0;
        next_reg <= 1'b0;
    end else begin
        // CPU ghi lệnh vào thanh ghi 16
        if (write && address == 5'd16) begin
            init_reg <= writedata[0]; // Bit 0: Khởi tạo băm mới (Init)
            next_reg <= writedata[1]; // Bit 1: Băm khối tiếp theo (Next)
        end else begin

            init_reg <= 1'b0;
            next_reg <= 1'b0;
        end
    end
end

always @(posedge clk or negedge reset_n) begin
    if(!reset_n)
        done_reg <= 1'b0;
    else begin
        // Xóa cờ done khi CPU gửi lệnh start (init/next) mới
        if(write && address == 5'd16 && (writedata[0] || writedata[1]))
            done_reg <= 1'b0;
        // Chốt cờ done khi lõi tính xong
        else if(digest_valid)
            done_reg <= 1'b1;
    end
end

always @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
        block_reg <= 512'd0;
    end else begin
        if(write) begin
            case(address)
 
                5'd0:  block_reg[511:480] <= writedata; // Word 0
                5'd1:  block_reg[479:448] <= writedata;
                5'd2:  block_reg[447:416] <= writedata;
                5'd3:  block_reg[415:384] <= writedata;
                5'd4:  block_reg[383:352] <= writedata;
                5'd5:  block_reg[351:320] <= writedata;
                5'd6:  block_reg[319:288] <= writedata;
                5'd7:  block_reg[287:256] <= writedata;
                5'd8:  block_reg[255:224] <= writedata;
                5'd9:  block_reg[223:192] <= writedata;
                5'd10: block_reg[191:160] <= writedata;
                5'd11: block_reg[159:128] <= writedata;
                5'd12: block_reg[127:96]  <= writedata;
                5'd13: block_reg[95:64]   <= writedata;
                5'd14: block_reg[63:32]   <= writedata;
                5'd15: block_reg[31:0]    <= writedata; // Word 15
                default: ;
            endcase
        end
    end
end


always @(*) begin
    readdata = 32'd0;
    if(read) begin
        case(address)

            5'd16: readdata = {29'd0, digest_valid, ready, done_reg};
            5'd25: readdata = {31'd0, digest_valid};

            5'd17: readdata = digest[255:224]; // H0
            5'd18: readdata = digest[223:192];
            5'd19: readdata = digest[191:160];
            5'd20: readdata = digest[159:128];
            5'd21: readdata = digest[127:96];
            5'd22: readdata = digest[95:64];
            5'd23: readdata = digest[63:32];
            5'd24: readdata = digest[31:0];    // H7
            default: readdata = 32'd0;
        endcase
    end
end

sha_core SHA_CORE (
    .clk(clk),
    .reset_n(reset_n),
    .init(init_reg),
    .next(next_reg),
    .mode(1'b1),
    .block(block_reg),
    .ready(ready),
    .digest(digest),
    .digest_valid(digest_valid)
);

endmodule
`default_nettype wire