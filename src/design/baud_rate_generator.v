module baud_rate_generator#(parameter clk_freq=100000000, parameter baud_rate=2400)(sys_clk,sys_rst,baud_clk);
input sys_clk,sys_rst;
output reg baud_clk;

localparam div=clk_freq/(baud_rate*16);

reg [$clog2(div)-1:0] count;

always@(posedge sys_clk or negedge sys_rst) begin
    if(!sys_rst) begin
        count<=0;
        baud_clk<=0;
    end
    else begin
        if(count == (div/2)-1) begin
            count<=0;
            baud_clk<=~baud_clk;
        end
        else begin
            count<=count+1;
        end
    end
end

endmodule
