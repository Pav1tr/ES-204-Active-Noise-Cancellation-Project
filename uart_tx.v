`timescale 1ns / 1ps
module uart_tx #(
    parameter CLK_FREQ  = 100_000_000,   
    parameter BAUD_RATE = 115200         // Baud rate
)(
    input clk,
    input reset,
    input tx_start,         
    input [7:0] tx_data,      //transmitting bytes
    output reg tx_serial,     //the serial output
    output reg tx_busy        //shoes that tx is high 
);

  //we initialise tick count separately such that as per requirement one can change his/her
  //clock freq and the baud rate
  localparam BAUD_TICK_COUNT =CLK_FREQ/BAUD_RATE; 
  reg [15:0] baud_counter;
  reg [3:0] bit_index;
  //we use a 10 bit shift register for transmiison
  reg [9:0] shift_reg; 
  
  localparam STATE_IDLE = 0, STATE_TRANSMIT = 1;
  reg state;

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      state        <= STATE_IDLE;
      tx_serial    <= 1'b1;     
      baud_counter <= 0;
      bit_index    <= 0;
      tx_busy      <= 1'b0;
      shift_reg    <= 10'b0;
    end else begin
      case(state)
        STATE_IDLE: begin
          tx_serial    <= 1'b1;
          baud_counter <= 0;
          bit_index    <= 0;
          tx_busy      <= 1'b0;
          if(tx_start) begin
            //we now load the shift register: start=0; stop=1
            shift_reg <= {1'b1, tx_data, 1'b0};
            state     <= STATE_TRANSMIT;
            tx_busy   <= 1'b1;
          end
        end

        STATE_TRANSMIT: begin
          if(baud_counter < BAUD_TICK_COUNT - 1) begin
            baud_counter <= baud_counter + 1;
          end else begin
            baud_counter <= 0;
            //transmit to lsb
            tx_serial <= shift_reg[0];
            // shift to right;shift in 1's at the MSB to maintain stop bits.
            shift_reg <= {1'b1, shift_reg[9:1]};
            if(bit_index < 9) begin
              bit_index <= bit_index + 1;
            end else begin
              //transmission done 
              state   <= STATE_IDLE;
              tx_busy <= 1'b0;
            end
          end
        end
        
        default: state <= STATE_IDLE;
      endcase
    end
  end

endmodule
