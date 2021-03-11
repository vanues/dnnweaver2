`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/03/09 20:55:27
// Design Name: 
// Module Name: mem_walker_stride_testbench
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


module mem_walker_stride_testbench();
    parameter integer  CLK_P=100;
    parameter integer  ADDR_WIDTH = 48;
    parameter integer  ADDR_STRIDE_W = 16;
    parameter integer  LOOP_ID_W = 5; 
    
    reg clk=1;
    reg reset=0;
    // From loop controller
    reg [ ADDR_WIDTH -1 : 0 ] base_addr;
    reg loop_ctrl_done;
    reg [ LOOP_ID_W  -1 : 0 ] loop_index;
    reg loop_index_valid;
    reg loop_init;
    reg loop_enter;
    reg loop_exit;
    // Address offset - from instruction decoder
    reg cfg_addr_stride_v;
    reg [ ADDR_STRIDE_W  -1 : 0 ] cfg_addr_stride;
    wire [ ADDR_WIDTH -1 : 0 ] addr_out;//output
    wire addr_out_valid;//output
    
    mem_walker_stride#() mws_inst(clk,reset,base_addr,loop_ctrl_done,loop_index,loop_index_valid,loop_init,loop_enter,loop_exit,
        cfg_addr_stride_v,cfg_addr_stride,addr_out,addr_out_valid);
    
    
    always#(CLK_P/2) clk=~clk;

    integer i;
    initial begin
        for(i=0;i<=(1<<LOOP_ID_W);i=i+1)begin
            mws_inst.stride_buf.mem[i] = i*2+1;
            mws_inst.offset_buf.mem[i] = i;
        end
    end
    
    initial begin
        #CLK_P;
        forever begin
            loop_index <= loop_index +1'b1;
            cfg_addr_stride <= cfg_addr_stride + 2'b10;
            #CLK_P;
        end
    end
    initial begin
        reset<=1;
        base_addr = 'b0;
        loop_enter <= 0;
        loop_init <= 0;
        loop_exit <= 0;
        cfg_addr_stride_v<= 0;
        loop_index_valid <= 0;
        loop_ctrl_done <= 0;
        cfg_addr_stride <= 'b0;
        loop_index <= 'b0;
        #CLK_P;
        reset<=0;
    end
    
    initial begin
        #CLK_P;
        
        #CLK_P;
        loop_enter <= 0;
        cfg_addr_stride_v <= 1;
        
        #CLK_P;
        #CLK_P;
        #CLK_P;
        //cfg_addr_stride_v <= 0;
        //loop_ctrl_done <= 1;
    end
    
endmodule
