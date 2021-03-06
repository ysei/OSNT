/*******************************************************************************
 *
 *  NetFPGA-10G http://www.netfpga.org
 *
 *  File:
 *        osnt_extract_metadata.v
 *
 *  Library:
 *        osnt/pcores/osnt_extract_metadata_v1_00_a
 *
 *  Module:
 *        nf10_extract_metadata
 *
 *  Author:
 *        Muhammad Shahbaz
 *
 *  Description:
 *
 *
 *  Copyright notice:
 *        Copyright (C) 2010, 2011 The Board of Trustees of The Leland Stanford
 *                                 Junior University
 *
 *  Licence:
 *        This file is part of the NetFPGA 10G development base package.
 *
 *        This file is free code: you can redistribute it and/or modify it under
 *        the terms of the GNU Lesser General Public License version 2.1 as
 *        published by the Free Software Foundation.
 *
 *        This package is distributed in the hope that it will be useful, but
 *        WITHOUT ANY WARRANTY; without even the implqied warranty of
 *        MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *        Lesser General Public License for more details.
 *
 *        You should have received a copy of the GNU Lesser General Public
 *        License along with the NetFPGA source package.  If not, see
 *        http://www.gnu.org/licenses/.
 *
 */

// TODO:
// (1) Optimize the code using generate
// (2) Add per queue (correct) enable/disbale support

`uselib lib=unisims_ver
`uselib lib=proc_common_v3_00_a

module osnt_extract_metadata
#(
  parameter C_S_AXI_DATA_WIDTH   = 32,
  parameter C_S_AXI_ADDR_WIDTH   = 32,
  parameter C_BASEADDR           = 32'hFFFFFFFF,
  parameter C_HIGHADDR           = 32'h00000000,
  parameter C_USE_WSTRB          = 0,
  parameter C_DPHASE_TIMEOUT     = 0,
  parameter C_S_AXI_ACLK_FREQ_HZ = 100,
  parameter C_M_AXIS_DATA_WIDTH  = 256,
  parameter C_S_AXIS_DATA_WIDTH  = 256,
  parameter C_M_AXIS_TUSER_WIDTH = 128,
  parameter C_S_AXIS_TUSER_WIDTH = 128,
	parameter C_TUSER_TIMESTAMP_POS = 32,
  parameter SIM_ONLY             = 0
)
(
  // Slave AXI Ports
  input                                           s_axi_aclk,
  input                                           s_axi_aresetn,
  input      [C_S_AXI_ADDR_WIDTH-1:0]             s_axi_awaddr,
  input                                           s_axi_awvalid,
  input      [C_S_AXI_DATA_WIDTH-1:0]             s_axi_wdata,
  input      [C_S_AXI_DATA_WIDTH/8-1:0]           s_axi_wstrb,
  input                                           s_axi_wvalid,
  input                                           s_axi_bready,
  input      [C_S_AXI_ADDR_WIDTH-1:0]             s_axi_araddr,
  input                                           s_axi_arvalid,
  input                                           s_axi_rready,
  output                                          s_axi_arready,
  output     [C_S_AXI_DATA_WIDTH-1:0]             s_axi_rdata,
  output     [1:0]                                s_axi_rresp,
  output                                          s_axi_rvalid,
  output                                          s_axi_wready,
  output     [1:0]                                s_axi_bresp,
  output                                          s_axi_bvalid,
  output                                          s_axi_awready,

  // Master Stream Ports (interface to data path)
  output     [C_M_AXIS_DATA_WIDTH-1:0]            m_axis_tdata,
  output     [((C_M_AXIS_DATA_WIDTH/8))-1:0]      m_axis_tstrb,
  output     [C_M_AXIS_TUSER_WIDTH-1:0]           m_axis_tuser,
  output                                          m_axis_tvalid,
  input                                           m_axis_tready,
  output                                          m_axis_tlast,
	
  // Slave Stream Ports (interface to RX queues)
  input      [C_S_AXIS_DATA_WIDTH-1:0]            s_axis_tdata,
  input      [((C_S_AXIS_DATA_WIDTH/8))-1:0]      s_axis_tstrb,
  input      [C_S_AXIS_TUSER_WIDTH-1:0]           s_axis_tuser,
  input                                           s_axis_tvalid,
  output                                          s_axis_tready,
  input                                           s_axis_tlast
);

  // -- Internal Parameters
  localparam NUM_RW_REGS = 2;
  localparam NUM_WO_REGS = 0;
  localparam NUM_RO_REGS = 0;

  // -- Signals
	wire																						axi_aclk;
	wire																						axi_aresetn;
	
  wire [NUM_RW_REGS*C_S_AXI_DATA_WIDTH-1:0]   		rw_regs;

  wire                                            sw_rst;
	wire																						em_enable;
	
	// -- Assignments
	assign		axi_aclk  =  s_axi_aclk;
	assign    axi_aresetn = s_axi_aresetn;

  // -- AXILITE Registers
  axi_lite_regs
  #(
    .C_S_AXI_DATA_WIDTH   (C_S_AXI_DATA_WIDTH),
    .C_S_AXI_ADDR_WIDTH   (C_S_AXI_ADDR_WIDTH),
    .C_USE_WSTRB          (C_USE_WSTRB),
    .C_DPHASE_TIMEOUT     (C_DPHASE_TIMEOUT),
    .C_BAR0_BASEADDR      (C_BASEADDR),
    .C_BAR0_HIGHADDR      (C_HIGHADDR),
    .C_S_AXI_ACLK_FREQ_HZ (C_S_AXI_ACLK_FREQ_HZ),
    .NUM_RW_REGS          (NUM_RW_REGS),
    .NUM_WO_REGS          (NUM_WO_REGS),
    .NUM_RO_REGS          (NUM_RO_REGS)
  )
    axi_lite_regs_1bar_inst
  (
    .s_axi_aclk      			(s_axi_aclk),
    .s_axi_aresetn   			(s_axi_aresetn),
    .s_axi_awaddr    			(s_axi_awaddr),
    .s_axi_awvalid   			(s_axi_awvalid),
    .s_axi_wdata     			(s_axi_wdata),
    .s_axi_wstrb     			(s_axi_wstrb),
    .s_axi_wvalid    			(s_axi_wvalid),
    .s_axi_bready    			(s_axi_bready),
    .s_axi_araddr    			(s_axi_araddr),
    .s_axi_arvalid   			(s_axi_arvalid),
    .s_axi_rready    			(s_axi_rready),
    .s_axi_arready   			(s_axi_arready),
    .s_axi_rdata     			(s_axi_rdata),
    .s_axi_rresp     			(s_axi_rresp),
    .s_axi_rvalid    			(s_axi_rvalid),
    .s_axi_wready    			(s_axi_wready),
    .s_axi_bresp     			(s_axi_bresp),
    .s_axi_bvalid    			(s_axi_bvalid),
    .s_axi_awready   			(s_axi_awready),
                     			
    .rw_regs         			(rw_regs),
		.rw_defaults     			((SIM_ONLY == 0) ? {NUM_RW_REGS*C_S_AXI_DATA_WIDTH{1'b0}} :
													 {
														 {31'b0, 1'b0}, //sw_enable
														 {31'b0, 1'b0} // sw_rst
													 }
													), 
		.wo_regs         			(),
		.wo_defaults     			({NUM_WO_REGS*C_S_AXI_DATA_WIDTH{1'b0}}),
		.ro_regs         			()
  );
  

  // -- Register assignments

  assign sw_rst         = rw_regs[(C_S_AXI_DATA_WIDTH*0)+1-1:(C_S_AXI_DATA_WIDTH*0)];
	assign em_enable      = rw_regs[(C_S_AXI_DATA_WIDTH*1)+1-1:(C_S_AXI_DATA_WIDTH*1)];

  // -- Extract Metadata
  extract_metadata #
  (
    .C_M_AXIS_DATA_WIDTH   ( C_M_AXIS_DATA_WIDTH ),
    .C_S_AXIS_DATA_WIDTH   ( C_S_AXIS_DATA_WIDTH ),
    .C_M_AXIS_TUSER_WIDTH  ( C_M_AXIS_TUSER_WIDTH ),
    .C_S_AXIS_TUSER_WIDTH  ( C_S_AXIS_TUSER_WIDTH ),
    .C_S_AXI_DATA_WIDTH    ( C_S_AXI_DATA_WIDTH ),
		.C_TUSER_TIMESTAMP_POS ( C_TUSER_TIMESTAMP_POS ),
		.SIM_ONLY							 ( SIM_ONLY )
		
   )
     extract_metadata_inst
   (
    // Global Ports
    .axi_aclk             ( axi_aclk ),
    .axi_aresetn          ( axi_aresetn ),

    // Master Stream Ports (interface to data path)
	  .m_axis_tdata       	( m_axis_tdata ),
    .m_axis_tstrb       	( m_axis_tstrb ),
    .m_axis_tuser       	( m_axis_tuser ),
    .m_axis_tvalid      	( m_axis_tvalid ),
    .m_axis_tready      	( m_axis_tready ),
    .m_axis_tlast       	( m_axis_tlast ),

    // Slave Stream Ports (interface to RX queues)
    .s_axis_tdata         ( s_axis_tdata ),
    .s_axis_tstrb         ( s_axis_tstrb ),
    .s_axis_tuser         ( s_axis_tuser ),
    .s_axis_tvalid        ( s_axis_tvalid ),
    .s_axis_tready        ( s_axis_tready ),
    .s_axis_tlast         ( s_axis_tlast ),

    // Misc
		.em_enable						( em_enable ),
		
    .sw_rst               ( sw_rst )
  );

endmodule
