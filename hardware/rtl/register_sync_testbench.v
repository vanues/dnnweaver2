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
    reg[WIDTH-1:0] indata;
    wire[WIDTH-1:0] outdata;
    
    initial clk=0;
    always#50 clk=~clk;
    
    initial begin
        indata = 8'b0;
       repeat(5)begin
            indata = indata + 1'b1; 
            #100; 
       end
    end
    
    register_sync#(WIDTH) rs_0(
        .clk(clk),
        .reset(0),
        .in(indata),
        .out(outdata)
    );
    

    
endmodule
