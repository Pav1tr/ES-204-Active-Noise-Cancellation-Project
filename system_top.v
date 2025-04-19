`timescale 1ns / 1ps

module system_top(
    input  wire       clk,        
    input  wire       conv,//switch to invoke convolution_top       
    input  wire       transmit,//switch for bram to uart     
    output wire       conv_done,//this acts as a latch which will ensure that convolution is done b4 tranmission is done   
    output wire       tx,// the tx pin(a18)       
    output wire [3:0] debug_led, // checking for convolution_top fsm satates
    output wire [7:0] dataout_top //just to check that convolution is done propelry
);

  // wire fr bram storing convolution
  wire        bram_ena;
  wire        bram_wea;
  wire [31:0]  bram_addr;
  wire signed [7:0]  bram_din;
  wire signed [7:0]  bram_dout;

  wire        ena_conv, wea_conv;
  wire [31:0]  addr_conv;
  wire signed [7:0]  din_conv;

  //signals required for thhe uart
  wire        ena_uart;wire [31:0]  addr_uart;

  //the final bram (we use both read amnd write for this )
  blk_mem_gen_A ram_inst (
    .clka   (clk),
    .ena    (bram_ena),
    .wea    (bram_wea),
    .addra  (bram_addr),
    .dina   (bram_din),
    .douta  (bram_dout)
  );

  //just to see that whether the convolution is properly happening or not
  assign dataout_top = bram_dout;

  //invoking convolution top
  convolution_top conv_inst (
    .clk       (clk),
    .reset     (~conv),     // active-high reset: hold ~conv=1 while idle
    .conv_done (conv_done),
    .debug_led (debug_led),
    .ena       (ena_conv),
    .wea       (wea_conv),
    .addr      (addr_conv),
    .din       (din_conv)
  );

  //invoking bram_to uart after conv_done is high
  bram_to_uart uart_inst (
    .clk        (clk),
    .reset      (~transmit),  //rest is jusgt the negation of transmit
    .conv_done  (conv_done),
    .ena        (ena_uart),
    .addr       (addr_uart),
    .dout       (bram_dout),
    .tx_serial  (tx)
  );

  //since wea is different for both the other modules ; we are using assign statements to change the wea pins for bram
  assign bram_ena  = ena_conv  | ena_uart;
  assign bram_wea  = wea_conv;         
  assign bram_addr = ena_conv  ? addr_conv
                     : addr_uart;
  assign bram_din  = ena_conv  ? din_conv
                     : 8'd0;

endmodule
