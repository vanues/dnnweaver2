`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/03/02 19:44:35
// Design Name: 
// Module Name: fifo_testbench
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


module fifo_testbench(

    );
    localparam DATA_WIDTH=8;
    localparam ADDR_WIDTH=3;//makes a 2^3=8 data spaces
    reg clk,reset;
    reg w_req,r_req;
    wire w_ready,r_ready,amst_full,amst_empty;//fifo output
    reg[DATA_WIDTH-1:0] write_data;
    wire[DATA_WIDTH-1:0] read_data;
    initial clk=0;
    always#50 clk=~clk;//period = 100
    
    fifo#(.DATA_WIDTH(DATA_WIDTH),.ADDR_WIDTH(ADDR_WIDTH)) fifo_inst(clk,reset,w_req,r_req,write_data,read_data,r_ready,w_ready,amst_full,amst_empty);
    
    initial begin
        reset<=1;
        write_data <= 8'ha0;
        #100;
        reset<=0;
        w_req<=1;r_req<=0;
        
        while(amst_full==1'b0 && w_ready)begin
            //$display("fifo:%d",fifo_inst.fifo_count);
            #100;
            write_data <= write_data + 1'b1;
             
        end
        w_req<=0;
        r_req<=1;
        
        while(amst_empty==1'b0 && r_ready)begin
            #50;
        end
        
    end
        
endmodule
