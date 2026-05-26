module rec #(parameter width=8)(
    input  wire             sys_clk,   
    input  wire             sys_rst,
    input  wire             baud_clk,
    input  wire             uart_rec_dataH,
    output reg  [width-1:0] rec_dataH,
    output reg              rec_readyH,
    output wire             rec_busy
);

    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;

    reg [1:0]       state;
    reg [3:0]       baud_count;
    reg [2:0]       index;
    reg [width-1:0] temp_reg;

//2Flip Flop Synchronizer
    reg [1:0] sync_reg;
    wire      uart_rec_sync;

    always @(posedge baud_clk or negedge sys_rst) begin
        if (!sys_rst) begin
            sync_reg <= 2'b11;
        end 
        else begin
            sync_reg <= {sync_reg[0], uart_rec_dataH};
        end
    end

    assign uart_rec_sync = sync_reg[1];

    assign rec_busy = (state != IDLE);

//FSM Logic
    always @(posedge baud_clk or negedge sys_rst) begin
        if (!sys_rst) begin
            state      <= IDLE;
            baud_count <= 0;
            index      <= 0;
            temp_reg   <= 0;
            rec_dataH  <= 0;
            rec_readyH <= 0;
        end 
        else begin
            rec_readyH <= 1'b0; // Default pulse to 0

            case(state)
                IDLE: begin
                    if (uart_rec_sync == 1'b0) begin
                        state      <= START;
                        baud_count <= 0;
                    end 
                    else begin
                        state <= IDLE;
                    end
                end

                START: begin
                    if (baud_count == 4'd7) begin
                        baud_count <= 0;
                        if (uart_rec_sync == 1'b0) begin
                            state <= DATA;
                            index <= 0;
                        end 
                        else begin
                            state <= IDLE;
                        end
                    end 
                    else begin
                        baud_count <= baud_count + 1;
                    end
                end

                DATA: begin
                    if (baud_count == 4'd15) begin
                        baud_count <= 0;
                        temp_reg[index] <= uart_rec_sync;
                        
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
                    if (baud_count == 4'd15) begin
                        state <= IDLE;
                        
                        // Framing Error Check: Only accept data if STOP bit is 1
                        if (uart_rec_sync == 1'b1) begin
                            rec_dataH  <= temp_reg;
                            rec_readyH <= 1'b1;
                        end
                    end 
                    else begin
                        baud_count <= baud_count + 1;
                    end
                end
                //coverage off
                default: begin
                    state <= IDLE;
                end
                //coverage on
            endcase
        end
    end
 
assign rec_busy = (state != IDLE);

endmodule
