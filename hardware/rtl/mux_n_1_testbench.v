`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/02/27 10:35:41
// Design Name: 
// Module Name: mux_n_1_testbench
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


module mux_n_1_testbench#(
    parameter integer LOG2_N= 2,
    parameter integer WIDTH = 8,
    parameter integer IN_WIDTH = (1<<LOG2_N)*WIDTH,//16bit
    parameter integer OUT_WIDTH = WIDTH
    
    )
();
    wire data_count  =1<<LOG2_N;
    wire[IN_WIDTH -1 :0] indata;
    wire[LOG2_N-1:0] sel[3:0];
    wire[WIDTH-1:0] outdata[3:0];
    
    assign sel[0] = 'd0;
    assign sel[1] = 'd1;
    assign sel[2] = 'd2;
    assign sel[3] = 'd3;
    assign indata = {8'ha,8'hb,8'hc,8'hd};
    mux_n_1 #(WIDTH,LOG2_N) mux_ins0(sel[0],indata,outdata[0]);
    mux_n_1 #(WIDTH,LOG2_N) mux_ins1(sel[1],indata,outdata[1]);
    mux_n_1 #(WIDTH,LOG2_N) mux_ins2(sel[2],indata,outdata[2]);
    mux_n_1 #(WIDTH,LOG2_N) mux_ins3(sel[3],indata,outdata[3]);

    initial begin
        #1 $finish;
    end
endmodule
