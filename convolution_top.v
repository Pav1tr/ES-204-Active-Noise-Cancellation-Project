`timescale 1ns / 1ps

module convolution_top(
    input  wire        clk,
    input  wire        reset,      // active-high synchronous reset
    output reg         conv_done,
    output reg [3:0]   debug_led,  // FSM state indicator
    output reg         ena,        // BRAM enable (for writes only)
    output reg         wea,        // BRAM write enable
    output reg [31:0]   addr,       // BRAM address 0..123
    output reg [7:0]   din         // BRAM data in
);

  //internal wires for BRam_audio and BRAM_weights
  reg  [31:0]  audio_addr, weight_addr;
  wire signed [7:0]  dout_audio, dout_weight;

  //calling bram wrappers
  BRAM_audio u_bram_audio (
    .clk  (clk),
    .en   (1'b1),
    .ren  (1'b1),
    .wen  (1'b0),
    .addr (audio_addr),
    .din  (8'd0),
    .dout (dout_audio)
  );

  BRAM_weights u_bram_weights (
    .clk  (clk),
    .en   (1'b1),
    .ren  (1'b1),
    .wen  (1'b0),
    .addr (weight_addr),
    .din  (8'd0),
    .dout (dout_weight)
  );

  //getting other intermediate wires and 
  reg signed[7:0]   audio_array [0:15];
  reg signed [7:0]   weight_array[0:15];
  reg signed [31:0]  conv_array  [0:30];

  reg [4:0]   load_index;  
  reg [4:0]   conv_k;      
  reg [4:0]   conv_i;
  reg signed [31:0] sum;
  reg [1:0]   byte_index;  
  reg [1:0]   wait_counter;
  reg [31:0]   out_addr;     

  // FSM State encoding
  localparam S_IDLE        = 4'd0,
             S_LOAD        = 4'd1,
             S_LOAD_WAIT   = 4'd2,
             S_CONV_INIT   = 4'd3,
             S_CONV_INNER  = 4'd4,
             S_CONV_STORE  = 4'd5,
             S_WRITE_INIT  = 4'd6,
             S_WRITE_WAIT  = 4'd7,
             S_WRITE_NEXT  = 4'd8,
             S_DONE        = 4'd9;

  reg [3:0] state;
  //starting fsm
  always @(posedge clk) begin
    if (reset) begin
      //initialising all to grounf values when the reset is on
      state         <= S_IDLE;
      conv_done     <= 1'b0;
      debug_led     <= 4'h0;
      load_index    <= 0;
      conv_k        <= 0;
      conv_i        <= 0;
      sum           <= 0;
      byte_index    <= 0;
      wait_counter  <= 0;
      out_addr      <= 0;
      audio_addr    <= 0;
      weight_addr   <= 0;
      ena           <= 1'b0;
      wea           <= 1'b0;
      addr          <= 0;
      din           <= 8'd0;
    end else begin
      //debug led mark the ongoing state of fsm
      debug_led <= state;

      case(state)
        //initialisation and the loading states 
        S_IDLE: begin
          conv_done   <= 1'b0;
          load_index  <= 0;
          state       <= S_LOAD;
        end

        S_LOAD: begin
          audio_addr    <= load_index;
          weight_addr   <= load_index;
          wait_counter  <= 0;
          state         <= S_LOAD_WAIT;
        end

        S_LOAD_WAIT: begin
          if (wait_counter < 2)
            wait_counter <= wait_counter + 1;
          else begin
            audio_array[load_index]  <= dout_audio;
            weight_array[load_index] <= dout_weight;
            if (load_index == 15) begin
              conv_k <= 0;
              state  <= S_CONV_INIT;
            end else begin
              load_index <= load_index + 1;
              state      <= S_LOAD;
            end
          end
        end

        //states for uthe convolution
        S_CONV_INIT: begin
          sum <= 0;
          if (conv_k < 15)
            conv_i <= 0;
          else
            conv_i <= conv_k - 15 + 1;
          state <= S_CONV_INNER;
        end

        S_CONV_INNER: begin
          if ((conv_i <= conv_k) && (conv_i < 16) && ((conv_k - conv_i) < 16)) begin
            sum   <= sum + (audio_array[conv_i])*(weight_array[conv_k - conv_i]);
            conv_i <= conv_i + 1;
          end else begin
            conv_array[conv_k] <= sum;
            state              <= S_CONV_STORE;
          end
        end

        S_CONV_STORE: begin
          byte_index <= 0;
          out_addr   <= conv_k * 4;  // each conv_k produces 4 bytes
          state      <= S_WRITE_INIT;
        end

        //bram wriiting 
        S_WRITE_INIT: begin
          // pick the correct byte of the 32-bit word
          din  <= conv_array[conv_k][8*byte_index +: 8];
          addr <= out_addr;
          ena  <= 1'b1;
          wea  <= 1'b1;
          wait_counter <= 0;
          state <= S_WRITE_WAIT;
        end

        S_WRITE_WAIT: begin
          if (wait_counter < 2)
            wait_counter <= wait_counter + 1;
          else begin
            ena <= 1'b0;
            wea <= 1'b0;
            state <= S_WRITE_NEXT;
          end
        end

        S_WRITE_NEXT: begin
          if (byte_index < 3) begin
            byte_index <= byte_index + 1;
            out_addr   <= out_addr + 1;
            state      <= S_WRITE_INIT;
          end else begin
            
            if (conv_k < 30) begin
              conv_k <= conv_k + 1;
              state  <= S_CONV_INIT;
            end else begin
              state <= S_DONE;
            end
          end
        end

        S_DONE: begin
          conv_done <= 1'b1;
          
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule
