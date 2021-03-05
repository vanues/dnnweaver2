`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/03/04 10:47:55
// Design Name: 
// Module Name: obuf_testbench
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
module obuf_testbench(

    );

  parameter integer  TAG_W                        = 2;
  parameter integer  MEM_DATA_WIDTH               = 64;
  parameter integer  ARRAY_M                      = 2;
  parameter integer  DATA_WIDTH                   = 32;
  parameter integer  BUF_ADDR_WIDTH               = 10;

  parameter integer  GROUP_SIZE                   = MEM_DATA_WIDTH / DATA_WIDTH;
  parameter integer  GROUP_ID_W                   = GROUP_SIZE == 1 ? 0 : $clog2(GROUP_SIZE);
  parameter integer  BUF_ID_W                     = $clog2(ARRAY_M) - GROUP_ID_W;

  parameter integer  MEM_ADDR_WIDTH               = BUF_ADDR_WIDTH + BUF_ID_W;
  parameter integer  BUF_DATA_WIDTH               = ARRAY_M * DATA_WIDTH;
  
  
  reg clk=1,reset=0;
  reg mem_read_req=0,mem_write_req=0;
  reg buf_read_req=0,buf_write_req=0;
  
  wire[MEM_DATA_WIDTH -1 : 0 ] mem_read_data;
  wire[BUF_DATA_WIDTH -1 : 0 ] buf_read_data;
  
  reg[MEM_ADDR_WIDTH -1 : 0 ] mem_read_addr,mem_write_addr;
  reg [ BUF_ADDR_WIDTH -1 : 0 ] buf_read_addr,buf_write_addr;
  
  reg[ MEM_DATA_WIDTH -1 : 0 ] mem_write_data;
  reg [ BUF_DATA_WIDTH -1 : 0 ] buf_write_data;
  
  always#50 clk= ~clk; //pe:100;
  
  initial begin
    reset=1;
    #200;
    mem_write_req <=1;
    mem_write_addr <='d0;
    mem_write_data <= 'd0;
    repeat(8)begin
        #100;
        mem_write_addr <= mem_write_addr + 1'b1;
        mem_write_data <= mem_write_data + 1'b1;
    end
  end
  
  initial begin
    #300;
    mem_read_req <=1;buf_read_req<=1;//only read mem_req
    mem_read_addr <= 'd0;
    buf_read_addr <= 'd1;
    repeat(8)begin
        #100;
        mem_read_addr <= mem_read_addr + 1'b1;
        buf_read_addr <= buf_read_addr + 1'b1;
    end
    
  end
  
  obuf#(TAG_W,MEM_DATA_WIDTH,ARRAY_M,DATA_WIDTH,BUF_ADDR_WIDTH) 
    obuf_ins(clk,reset,mem_read_req,mem_read_addr,mem_read_data,mem_write_req,mem_write_addr,mem_write_data
           ,buf_read_req,buf_read_addr,buf_read_data,buf_write_req,buf_write_addr,buf_write_data);
           
           
  
endmodule
  