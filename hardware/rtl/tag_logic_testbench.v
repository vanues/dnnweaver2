`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/03/04 17:17:58
// Design Name: 
// Module Name: tag_logic_testbench
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


module tag_logic_testbench(

    );
    reg clk=0,reset=0,tag_req=0,compute_tag_done=0,ldmem_tag_done=0,stmem_tag_done=0;

    wire tag_reuse;
    wire tag_bias_prev_sw;
    wire tag_ddr_pe_sw;
    reg tag_flush;
    
    wire tag_ready;//output
    wire tag_done;//output
    wire next_compute_tag;//output
    wire compute_bias_prev_sw;//output
    wire compute_tag_ready;//output
    wire ldmem_tag_ready;//output
    wire stmem_ddr_pe_sw;//output
    wire stmem_tag_ready;//output
    
    tag_logic#(1) tl_inst(clk,reset,tag_req,tag_reuse,tag_bias_prev_sw,tag_ddr_pe_sw,tag_ready,tag_done,tag_flush,compute_tag_done,
        next_compute_tag,compute_bias_prev_sw,compute_tag_ready,ldmem_tag_done,ldmem_tag_ready,stmem_tag_done,stmem_ddr_pe_sw,stmem_tag_ready);
        
    always#50 clk=~clk;
    
    initial begin
        reset<=1;
        #150;
        reset<=0;
        tag_req<=1;
        compute_tag_done <=1;
        #100;
        ldmem_tag_done<=1;
        #100;
        
        #100;
        tag_flush <=1;
        #100;
        stmem_tag_done <=1;
    end
endmodule
