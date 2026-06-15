`default_nettype none

module top (
    input  wire CLOCK_50,   
    input  wire [0:0] KEY,  
 
    inout  [35:0] GPIO_1 
);

    // Instantiate hệ thống Nios II đã tạo từ Qsys
    system nios2_system (
        .clk_clk            (CLOCK_50), 
        .reset_reset_n      (KEY[0]),   
        
        // Nối các cổng export từ Qsys ra các chân vật lý bên trên
        .lcd_scl_pin_export (GPIO_1[1]), 
        .lcd_sda_pin_export (GPIO_1[0])  
    );
	 assign GPIO_1[35:4] = {32{1'bz}};

endmodule
`default_nettype wire