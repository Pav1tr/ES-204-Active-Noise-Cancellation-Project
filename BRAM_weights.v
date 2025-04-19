module BRAM_weights(clk, en, ren, wen, addr, din, dout);
input clk, en, wen, ren;
input [3:0] addr;
input [7:0] din;
output [7:0] dout;
blk_mem_gen_0 inst3(.clka(clk),.ena((en&ren)|(en&wen)),.wea(wen),.addra(addr),.dina(din),.douta(dout));
endmodule
