`timescale 1ns / 1ns
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/02/26 16:10:18
// Design Name: 
// Module Name: mux_2_1_testbench
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


module mux_2_1_testbench();
    wire[7:0] data1,data2,dataout;
    wire[15:0] sumdata;
    wire sel0,sel1;

    assign data1 = 8'b11110000;
    assign data2 = 8'b00001111;
    assign sel1 = 1;
    assign sel0 = 1;
    assign sumdata = {data1,data2};
    
    mux_2_1#(8) ins1(sel1,sumdata,dataout);
    mux_2_1#(8) ins0(sel0,sumdata,dataout);
    
endmodule
