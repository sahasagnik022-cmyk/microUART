module txmit #(parameter width=8)(
    input  wire             sys_clk,    
    input  wire             sys_rst,
    input  wire             baud_clk,
    input  wire             xmitH,
    input  wire [width-1:0] xmit_dataH,
    output wire             xmit_doneH,
    output wire             xmit_active,
    output reg              uart_xmit_dataH
);

    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;

    reg [1:0]       state;
    reg [2:0]       index;          
    reg [width-1:0] data;
    reg [3:0]       baud_count;


//FSM Logic
    always @(posedge baud_clk or negedge sys_rst) begin
        if (!sys_rst) begin
            state           <= IDLE;
            uart_xmit_dataH <= 1'b1;
            index           <= 0;
            data            <= 0;
            baud_count      <= 0;
        end 
        else begin
            case(state)
                IDLE: begin
                    uart_xmit_dataH <= 1'b1;
                    if (xmitH) begin
                        state      <= START;
                        data       <= xmit_dataH;
                        index      <= 0;
                        baud_count <= 0;
                    end 
                    else begin
                        state <= IDLE;
                    end
                end

                START: begin
                    uart_xmit_dataH <= 1'b0;
                    if (baud_count == 4'd15) begin
                        state      <= DATA;
                        baud_count <= 0;
                    end 
                    else begin
                        baud_count <= baud_count + 1;
                    end
                end
                
                DATA: begin
                    uart_xmit_dataH <= data[index];
                    if (baud_count == 4'd15) begin
                        baud_count <= 0;
                        if (index == 3'd7) begin
                            state <= STOP;
                        end 
                        else begin
                            index <= index + 1;
                        end
                    end 
                    else begin
                        baud_count <= baud_count + 1;
                    end
                end
                
                STOP: begin
                    uart_xmit_dataH <= 1'b1;
                    if (baud_count == 4'd15) begin
                        // IDLE Bypass for Continuous Transmission
                        if (xmitH) begin
                            state      <= START;
                            index      <= 0;
                            baud_count <= 0;
                            data       <= xmit_dataH;
                        end 
                        else begin
                            state <= IDLE;
                        end
                    end 
                    else begin
                        baud_count <= baud_count + 1;
                    end
                end
               //coverage off 
                default: begin
                    state           <= IDLE;
                    uart_xmit_dataH <= 1'b1;
                end
                //coverage on
            endcase
        end
    end

    assign xmit_active = (state != IDLE);
    
    assign xmit_doneH = (state == STOP) && (baud_count == 4'd15);

endmodule
