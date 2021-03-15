`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/03/15 16:21:33
// Design Name: 
// Module Name: controller_fsm_testbench
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


module controller_fsm_testbench();
  parameter integer  LOOP_ID_W = 5;
  parameter integer  LOOP_ITER_W = 16;
  parameter integer  IMEM_ADDR_W = 5;
  // Internal Parameters
  parameter integer  STATE_W   = 3;
  parameter integer  LOOP_STATE_W = LOOP_ID_W;
  parameter integer  STACK_DEPTH = (1 << IMEM_ADDR_W);
  
  reg clk=1,reset=1;
  wire done;
  reg start,stall;
  reg cfg_loop_iter_v;
  reg  [ LOOP_ITER_W   -1 : 0 ] cfg_loop_iter;
  reg  [ LOOP_ID_W     -1 : 0 ] cfg_loop_iter_loop_id;
  wire [LOOP_ID_W -1 : 0 ] loop_index;
  wire loop_index_valid;
  wire loop_last_iter;
  wire loop_init;
  wire loop_enter;
  wire loop_exit;
  
  
  always#50 clk=~clk;
  initial begin
    start<=0;
    stall<=0;
    cfg_loop_iter_v <=0;
    cfg_loop_iter <=0;
    cfg_loop_iter_loop_id <=0;
  end
    
    
  controller_fsm#() cof_inst(clk,reset,start,done,stall,cfg_loop_iter_v,cfg_loop_iter,cfg_loop_iter_loop_id,loop_index,loop_index_valid,
    loop_last_iter,loop_init,loop_enter,loop_exit);
    
endmodule
