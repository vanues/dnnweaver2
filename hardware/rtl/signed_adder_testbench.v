`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/03/01 10:57:34
// Design Name: 
// Module Name: signed_adder_testbench
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


module signed_adder_testbench(

    );
    localparam integer DTYPE = "FXP";//FXP,FP32,FP16
    localparam reg_output = "TRUE";//FASLE
    localparam integer IN1_WIDTH = 20;
    localparam integer IN2_WIDTH = 32;
    localparam integer OUT_WIDTH = 32;
    
    wire [IN1_WIDTH-1:0] a;
    wire [IN2_WIDTH-1:0] b;
    wire [OUT_WIDTH-1:0] out;
    
    reg clk,reset,enable;
    initial clk=0;
    always#100 clk=~clk;
    
    generate
    
        
        signed_adder#(DTYPE,reg_output,IN1_WIDTH,IN2_WIDTH,OUT_WIDTH) sa_0(
            .clk(clk),
            .reset(reset),
            .enable(enable),
            .a(a),
            .b(b),
            .out(out)
        );
    
        assign a='h01234;
        assign b ='h1;
        initial begin
            reset=0;
            enable=0;
            #100 enable =1;
        end
    endgenerate;
    
endmodule
