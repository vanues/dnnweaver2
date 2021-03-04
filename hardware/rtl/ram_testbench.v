`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/02/27 16:12:20
// Design Name: 
// Module Name: ram_testbench
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


module ram_testbench(
    
    );
    localparam integer DATA_WIDTH=10;
    localparam integer ADDR_WIDTH=12;
    localparam integer OUTPUT_REG=1;
    
    wire [ADDR_WIDTH-1:0] read_addr,write_addr;
    wire [DATA_WIDTH-1:0] to_read_data,to_write_data;
    wire read_req,write_req;
    
    
    reg clk;
    initial clk=0;
    always#100 clk=~clk;
    
    reg reset;
    generate
        assign read_req=1;
        assign read_addr = 5;
        
        assign write_req = 1;
        assign write_addr = 5;
        assign to_write_data = 10'hf;
        initial begin
            reset=0;
            //#240 reset=1;
           
            #350 reset=1;
            #400 reset=0;
        end
        ram#(DATA_WIDTH,ADDR_WIDTH,OUTPUT_REG) ram_ini1(clk,reset,read_req,read_addr,to_read_data,write_req,write_addr,to_write_data);
    endgenerate
    
endmodule
