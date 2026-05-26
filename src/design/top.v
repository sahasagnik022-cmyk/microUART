module top#(parameter width=8, parameter clk_freq=100000000, parameter baud_rate=2400)(sys_clk,sys_rst,xmitH,xmit_dataH,uart_rec_dataH,uart_xmit_dataH,xmit_doneH,rec_dataH,rec_readyH,rec_busy,xmit_active);
input sys_clk,sys_rst,xmitH;
input [width-1:0]xmit_dataH;
input uart_rec_dataH;
output uart_xmit_dataH,xmit_doneH,rec_readyH,rec_busy,xmit_active;
output [width-1:0] rec_dataH;

wire baud_clk;

baud_rate_generator #(.clk_freq(clk_freq),.baud_rate(baud_rate)) brg(.sys_clk(sys_clk),.sys_rst(sys_rst),.baud_clk(baud_clk));

txmit #(.width(width)) tx(.sys_clk(sys_clk),.sys_rst(sys_rst),.baud_clk(baud_clk),.xmitH(xmitH),.xmit_dataH(xmit_dataH),.xmit_doneH(xmit_doneH),.xmit_active(xmit_active),.uart_xmit_dataH(uart_xmit_dataH));

rec #(.width(width)) rx(.sys_clk(sys_clk),.sys_rst(sys_rst),.baud_clk(baud_clk),.rec_readyH(rec_readyH),.rec_busy(rec_busy),.rec_dataH(rec_dataH),.uart_rec_dataH(uart_rec_dataH));


endmodule

