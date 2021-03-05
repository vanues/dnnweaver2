//
// Tag logic for double buffering
//
// Hardik Sharma
// (hsharma@gatech.edu)

/*
module sum:
finite time mache for tag_state
*/
`timescale 1ns/1ps
module tag_logic #(
    parameter integer  STORE_ENABLED                = 1
)
(
    input  wire                                         clk,
    input  wire                                         reset,
    input  wire                                         tag_req,
    input  wire                                         tag_reuse,
    input  wire                                         tag_bias_prev_sw,//sw for switch?
    input  wire                                         tag_ddr_pe_sw,
    output wire                                         tag_ready,//output
    output wire                                         tag_done,//output
    input  wire                                         tag_flush,
    input  wire                                         compute_tag_done,
    output wire                                         next_compute_tag,//output
//    output wire                                         compute_tag_reuse,
    output wire                                         compute_bias_prev_sw,//output
    output wire                                         compute_tag_ready,//output
    input  wire                                         ldmem_tag_done,
    output wire                                         ldmem_tag_ready,//output
    input  wire                                         stmem_tag_done,
    output wire                                         stmem_ddr_pe_sw,//output
    output wire                                         stmem_tag_ready//output
);

//==============================================================================
// Wires/Regs
//==============================================================================

    //TAG value flow should be 0-1-2-3-4                   trans if:
    localparam integer  TAG_FREE                     = 0;//tag_req == 1
    localparam integer  TAG_LDMEM                    = 1;//ldmem_tag_done == 1 
    localparam integer  TAG_COMPUTE                  = 2;//compute_tag_done == 1
    localparam integer  TAG_COMPUTE_CHECK            = 3;//tag_reuse_counter == 0 && tag_flush_state_q == 1 && STORE_ENABLED
    localparam integer  TAG_STMEM                    = 4;

    localparam integer  TAG_STATE_W                  = 3;//2^3=8个state

    localparam integer  REUSE_STATE_W                = 1;
    localparam integer  REUSE_FALSE                  = 0;//NEVER used
    localparam integer  REUSE_TRUE                   = 1;//NEVER used

    reg                                         tag_flush_state_d;//input d
    reg                                         tag_flush_state_q;//output q
    reg tag_reuse_state_d;
    reg tag_reuse_state_q;

    reg [2 : 0] tag_reuse_counter;

    reg                                         tag_ddr_pe_sw_q;
    reg                                         compute_ddr_pe_sw;
    reg                                         _stmem_ddr_pe_sw;
    reg                                         tag_bias_prev_sw_q;
    reg                                         reuse_tag_bias_prev_sw_q;
    reg  [ TAG_STATE_W          -1 : 0 ]        tag_state_d;
    reg  [ TAG_STATE_W          -1 : 0 ]        tag_state_q;
//==============================================================================

//==============================================================================
// Tag allocation
//==============================================================================
    //KEY var: tag_state_q's value
    assign tag_done = tag_state_q == TAG_FREE;//output

    assign ldmem_tag_ready = tag_state_q == TAG_LDMEM;//output
    assign compute_tag_ready = tag_state_q == TAG_COMPUTE;//output
    assign stmem_tag_ready = tag_state_q == TAG_STMEM;//output
    assign tag_ready = tag_state_q == TAG_FREE;//output

    assign compute_bias_prev_sw = tag_bias_prev_sw_q;//output
    assign stmem_ddr_pe_sw = _stmem_ddr_pe_sw;//output


  //FSM
  always @(*)
  begin: TAG0_STATE
    tag_state_d = tag_state_q;//保证tag_state_d至少有一个value（例如第一次运行）? TODO: 这句可以没有吗
    case (tag_state_q)

      TAG_FREE: begin// 0
        if (tag_req) begin
          tag_state_d = TAG_LDMEM;//set tag_state to 1
        end
      end

      TAG_LDMEM: begin// 1
        if (ldmem_tag_done)
          tag_state_d = TAG_COMPUTE;
      end

      TAG_COMPUTE: begin// 2
        if (compute_tag_done)
          tag_state_d = TAG_COMPUTE_CHECK;
      end

      TAG_COMPUTE_CHECK: begin// 3
        if (tag_reuse_counter == 0 && tag_flush_state_q == 1) begin
          if (STORE_ENABLED)
            tag_state_d = TAG_STMEM;
          else
            tag_state_d = TAG_FREE;//return to 0
        end
        else if (tag_reuse_counter != 0)
          tag_state_d = TAG_COMPUTE;
      end

      TAG_STMEM: begin// 4
        if (stmem_tag_done)
          tag_state_d = TAG_FREE;
      end
    endcase
  end

  //tag_state_q reg
  always @(posedge clk)
  begin
    if (reset) begin
      tag_state_q <= TAG_FREE;//set tag_state to 0(tag_free)
    end
    else begin
      tag_state_q <= tag_state_d;//正常模式，最新的status d to q
    end
  end
  //tag_flush_state_d check
  always @(*)
  begin
    tag_flush_state_d = tag_flush_state_q;//TODO: 这句可以删除吗
    case (tag_flush_state_q)
      0: begin
        if (tag_flush && (tag_state_q != TAG_FREE))
          tag_flush_state_d = 1;
      end
      1: begin
        if ((tag_state_q == TAG_COMPUTE_CHECK) && (tag_reuse_counter == 0))
          tag_flush_state_d = 0;
      end
    endcase
  end
  //tag_flush_state_q reg
  always @(posedge clk)
  begin
    if (reset)
      tag_flush_state_q <= 0;
    else
      tag_flush_state_q <= tag_flush_state_d;
  end

  assign next_compute_tag = (tag_state_q == TAG_COMPUTE_CHECK )&& (tag_flush_state_q == 1) && (tag_reuse_counter == 0);

  always @(posedge clk)
  begin
    if (reset)
      tag_reuse_counter <= 0;
    else begin
      if (compute_tag_done && ~(tag_req || tag_reuse) && tag_reuse_counter != 0)
        tag_reuse_counter <= tag_reuse_counter - 1'b1;
      else if (~compute_tag_done && (tag_reuse || tag_req))//KEY var: compute_tag_done
        tag_reuse_counter <= tag_reuse_counter + 1'b1;
    end
  end

  always @(posedge clk)
  begin
    if (reset) begin
      compute_ddr_pe_sw <= 1'b0;
    end else if (ldmem_tag_done || tag_state_q == TAG_COMPUTE_CHECK) begin
      compute_ddr_pe_sw <= tag_ddr_pe_sw_q;
    end
  end

  always @(posedge clk)
  begin
    if (reset) begin
      _stmem_ddr_pe_sw <= 1'b0;
    end else if (compute_tag_done) begin
      _stmem_ddr_pe_sw <= compute_ddr_pe_sw;
    end
  end

  always @(posedge clk)
  begin
    if (reset) begin
      tag_bias_prev_sw_q <= 1'b0;
    end
    else if (tag_req && tag_ready) begin
      tag_bias_prev_sw_q <= tag_bias_prev_sw;
    end
    else if (compute_tag_done)
      tag_bias_prev_sw_q <= reuse_tag_bias_prev_sw_q;
  end

  always @(posedge clk)
  begin
    if (reset) begin
      tag_ddr_pe_sw_q <= 1'b0;
    end
    else if ((tag_req && tag_ready) || tag_reuse) begin
      tag_ddr_pe_sw_q <= tag_ddr_pe_sw;
    end
  end

  always @(posedge clk)
    if (reset)
      reuse_tag_bias_prev_sw_q <= 1'b0;
    else if (tag_reuse)
      reuse_tag_bias_prev_sw_q <= tag_bias_prev_sw;
//==============================================================================

//==============================================================================
// VCD
//==============================================================================
`ifdef COCOTB_TOPLEVEL_tag_logic
initial begin
  $dumpfile("tag_logic.vcd");
  $dumpvars(0, tag_logic);
end
`endif
//==============================================================================

endmodule
