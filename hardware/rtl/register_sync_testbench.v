`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/03/01 10:28:54
// Design Name: 
// Module Name: register_sync_testbench
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


module register_sync_testbench(
    
    );
    localparam integer WIDTH=8;
    reg clk;
    wire[WIDTH-1:0] indata,outdata;
    
    initial clk=0;
    always#100 clk=~clk;
    
    generate
    assign indata=8'hab;
    
    register_sync#(WIDTH) rs_0(
        .clk(clk),
        .reset(0),
        .in(indata),
        .out(outdata)
    );
    
    endgenerate
    
endmodule
