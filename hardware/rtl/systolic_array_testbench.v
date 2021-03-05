`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/03/05 14:41:51
// Design Name: 
// Module Name: systolic_array_testbench
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


module systolic_array_testbench(
    );
    parameter integer  ARRAY_N                      = 4;//MxN PEs
    parameter integer  ARRAY_M                      = 4;
    parameter          DTYPE                        = "FXP"; // FXP for Fixed-point; FP32 for single precision; FP16 for half-precision

    parameter integer  ACT_WIDTH                    = 16;
    parameter integer  WGT_WIDTH                    = 16;
    parameter integer  BIAS_WIDTH                   = 32;
    parameter integer  ACC_WIDTH                    = 48;

    // General
    parameter integer  MULT_OUT_WIDTH               = ACT_WIDTH + WGT_WIDTH;//d:32
    parameter integer  PE_OUT_WIDTH                 = MULT_OUT_WIDTH + $clog2(ARRAY_N);//d:48
    
    parameter integer  SYSTOLIC_OUT_WIDTH           = ARRAY_M * ACC_WIDTH;
    parameter integer  IBUF_DATA_WIDTH              = ARRAY_N * ACT_WIDTH;//4*16
    parameter integer  WBUF_DATA_WIDTH              = ARRAY_N * ARRAY_M * WGT_WIDTH;//4*4*16
    parameter integer  OUT_WIDTH                    = ARRAY_M * ACC_WIDTH;
    parameter integer  BBUF_DATA_WIDTH              = ARRAY_M * BIAS_WIDTH;
    // Address for buffers
    parameter integer  OBUF_ADDR_WIDTH              = 16;
    parameter integer  BBUF_ADDR_WIDTH              = 16;//
    
    reg clk=1;
    reg reset=1;
    
    reg acc_clear;
    reg  bias_read_req;
    reg  bias_prev_sw;
    reg  obuf_write_req;
    
    reg  [ IBUF_DATA_WIDTH -1 : 0 ] ibuf_read_data;//input act buffer data
    reg  [ WBUF_DATA_WIDTH -1 : 0 ] wbuf_read_data;//weight buffer data
    
    reg  [ BBUF_ADDR_WIDTH -1 : 0 ] bias_read_addr;
    reg  [ BBUF_DATA_WIDTH -1 : 0 ] bbuf_read_data;//bias data
    reg  [ OUT_WIDTH -1 : 0 ]       obuf_read_data;
    reg  [ OBUF_ADDR_WIDTH -1 : 0 ] obuf_read_addr;
    reg  [ OBUF_ADDR_WIDTH -1 : 0 ] obuf_write_addr;
    
    //output
    wire  sys_obuf_write_req;
    wire  sys_obuf_read_req;
    wire  sys_bias_read_req;
    wire  [ OBUF_ADDR_WIDTH -1 : 0 ] sys_obuf_read_addr;
    wire  [ OBUF_ADDR_WIDTH -1 : 0 ] sys_obuf_write_addr;
    wire  [ OUT_WIDTH -1 : 0 ]       obuf_write_data;
    wire  [ BBUF_ADDR_WIDTH -1 : 0 ] sys_bias_read_addr;
    
    systolic_array#() sa_inst(clk,reset,acc_clear,ibuf_read_data,sys_bias_read_req,sys_bias_read_addr,bias_read_req,bias_read_addr,bbuf_read_data,
        bias_prev_sw,wbuf_read_data,obuf_read_data,obuf_read_addr,sys_obuf_read_req,sys_obuf_read_addr,obuf_write_req,obuf_write_data,
        obuf_write_addr,sys_obuf_write_req,sys_obuf_write_addr);
    
    always#50 clk=~clk;
    
    initial begin
        ibuf_read_data = {4{16'h1111}};
        wbuf_read_data = {4{ibuf_read_data}};
        bbuf_read_data = {4{32'h43211234}}; 
        #100;
        reset<=0;
        obuf_write_req<='d1;
        //obuf_write_addr <= 'd0;
        bias_prev_sw <= 'd0;
    end
    
    
endmodule
