`timescale 1ns / 1ps

module bram_to_uart(
    input  wire       clk,
    input  wire       reset,     
    input  wire       conv_done,  // wait until convolution is done
    output reg        ena,        
    output reg [31:0]  addr,     
    input  wire signed [7:0] dout,    
    output wire       tx_serial   
);

  //calling uart core
  reg        uart_start;
  reg signed [7:0] uart_data;
  wire       uart_busy;

  uart_tx #(
    .CLK_FREQ (100_000_000),
    .BAUD_RATE(115200)
  ) u_uart_tx (
    .clk       (clk),
    .reset     (reset),
    .tx_start  (uart_start),
    .tx_data   (uart_data),
    .tx_serial (tx_serial),
    .tx_busy   (uart_busy)
  );

  //fsm
  localparam TOTAL_BYTES = 124;
  localparam S_WAIT_START  = 3'd0,
             S_READ_SETUP  = 3'd1,
             S_READ_WAIT   = 3'd2,
             S_UART_SEND   = 3'd3,
             S_WAIT_UART   = 3'd4,
             S_NEXT_ADDR   = 3'd5,
             S_DONE        = 3'd6;

  reg [2:0] state;
  reg [31:0] addr_ctr;
  reg [1:0] wait_ctr;
  reg       conv_latched;

  //checking for conv_done as the latch
  always @(posedge clk or posedge reset) begin
    if (reset)
      conv_latched <= 1'b0;
    else if (conv_done)
      conv_latched <= 1'b1;
  end

  always @(posedge clk) begin
    if (reset) begin
      state        <= S_WAIT_START;
      addr_ctr     <= 0;
      addr         <= 0;
      ena          <= 0;
      uart_start   <= 0;
      uart_data    <= 8'd0;
      wait_ctr     <= 0;
    end else begin
      case(state)
        S_WAIT_START: begin
          if (conv_latched)
            state <= S_READ_SETUP;
        end

        S_READ_SETUP: begin
          ena        <= 1'b1;
          addr       <= addr_ctr;
          wait_ctr   <= 0;
          state      <= S_READ_WAIT;
        end

        S_READ_WAIT: begin
          if (wait_ctr < 2)
            wait_ctr <= wait_ctr + 1;
          else begin
            uart_data  <= dout;
            ena        <= 1'b0;
            state      <= S_UART_SEND;
          end
        end

        S_UART_SEND: begin
          if (!uart_busy && !uart_start)
            uart_start <= 1'b1;
          else begin
            uart_start <= 1'b0;
            state      <= S_WAIT_UART;
          end
        end

        S_WAIT_UART: begin
          if (!uart_busy)
            state <= S_NEXT_ADDR;
        end

        S_NEXT_ADDR: begin
          if (addr_ctr < TOTAL_BYTES-1) begin
            addr_ctr <= addr_ctr + 1;
            state    <= S_READ_SETUP;
          end else begin
            state <= S_DONE;
          end
        end

        S_DONE: begin
          //done !!!
        end

        default: state <= S_WAIT_START;
      endcase
    end
  end

endmodule
