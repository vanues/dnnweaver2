`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/03/03 19:36:59
// Design Name: 
// Module Name: banked_ram_testbench
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


module banked_ram_testbench(

    );
    parameter integer  TAG_W                        = 2;
    parameter integer  NUM_TAGS                     = (1<<TAG_W);
    parameter integer  DATA_WIDTH                   = 16;
    parameter integer  ADDR_WIDTH                   = 13;
    parameter integer  LOCAL_ADDR_W                 = ADDR_WIDTH - TAG_W;
    
    reg clk=0,reset=0;
    reg s_read_req_a=0,s_read_req_b=0,s_write_req_a=0,s_write_req_b=0;
    reg[ADDR_WIDTH-1 : 0]  s_read_addr_a,s_read_addr_b,s_write_addr_a,s_write_addr_b;
    wire[DATA_WIDTH-1 : 0]  s_read_data_a,s_read_data_b;
    reg[DATA_WIDTH-1:0] s_write_data_a,s_write_data_b;
    
    always#50 clk=~clk;
    //0. 1 write
    //1. 1 write 1 read
    //2. 2 write
    
    initial begin
        reset=1;
        #100;
        
        s_write_req_a<=1;
       
        
        s_write_data_a <= 16'h0000;
        s_write_addr_a <= 16'b000_00000_0000_0000;
        
        repeat(10)begin
            #100;
            
            s_write_data_a <= s_write_data_a +16'h0001;
            s_write_addr_a <= s_write_addr_a +1'b1; 
           
        end
        
    end
    initial begin
        #100;
        
        s_write_req_b<=1;
       
        
        s_write_data_b <= 16'h0000;
        s_write_addr_b <= 16'b000_01000_0000_0000;
        
        repeat(10)begin
            #100;
            
            s_write_data_b <= s_write_data_b +16'h0011;
            s_write_addr_b <= s_write_addr_b +1'b1; 
           
        end
        
    end
    initial begin
        #200
        s_read_req_a<=1;
        s_read_addr_a <= 16'b000_00000_0000_0000;
        repeat(10)begin
            #100;
         
            s_read_addr_a <= s_read_addr_a +1'b1;
        end    
            
    end
    
    banked_ram#() br_ins(clk,reset,s_read_req_a,s_read_addr_a,s_read_data_a,s_write_req_a, s_write_addr_a,s_write_data_a,
        s_read_req_b,s_read_addr_b,s_read_data_b,s_write_req_b,s_write_addr_b,s_write_data_b);
        
        
endmodule
