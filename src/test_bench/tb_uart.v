`timescale 1ns / 1ps
`include "top.v"
`include "baud_rate_generator.v"
`include "txmit.v"
`include "rec.v"
//`include "uart_rx.v"
//`include "uart_tx.v"
//`include "baud_gen.v"
`include "uart_ref.v"
//`include "MicroUART.v"

module tb_uart();

    parameter width = 8;
    parameter clk_freq = 100_000_000;
    parameter baud_rate = 2400;

    localparam BIT_PERIOD = 1_000_000_000 / baud_rate; // In ns

    reg sys_clk;
    reg sys_rst;
    reg xmitH;
    reg  [width-1:0] xmit_dataH;
    wire xmit_active;
    wire xmit_doneH;
    wire uart_xmit_dataH;
    wire [width-1:0] rec_dataH;
    wire rec_readyH;
    wire rec_busy;
    // loopback connector TX-RX
    reg  loopback_en;
    reg  rx_force; // Manual error
    wire uart_rec_dataH;
    
    // If loopback is enabled, connect TX to RX. Or use manual force.
    assign uart_rec_dataH = loopback_en ? uart_xmit_dataH : rx_force;

    reg        sb_load;
    reg  [7:0] sb_expected;
    reg        sb_check;
    wire       sb_pass;
    wire       sb_fail;
    reg [7:0] random_data;

    integer pass_count = 0;
    integer fail_count = 0;
    integer i;

   top #(
        .width(width),
        .clk_freq(clk_freq),
        .baud_rate(baud_rate)
    ) dut (
        .sys_clk         (sys_clk),
        .sys_rst         (sys_rst),
        .xmitH           (xmitH),
        .xmit_dataH      (xmit_dataH),
        .xmit_active     (xmit_active),
        .xmit_doneH      (xmit_doneH),
        .uart_xmit_dataH (uart_xmit_dataH),
        .uart_rec_dataH  (uart_rec_dataH),
        .rec_dataH       (rec_dataH),
        .rec_readyH      (rec_readyH),
        .rec_busy        (rec_busy)
    );

/*    MicroUART #(
        .CLK_FREQ(clk_freq),
        .BAUD_RATE(baud_rate),
        .DATA_BITS(width)
    ) dut (
        .sys_clk(sys_clk),
        .sys_rst_l(sys_rst),
        .xmitH(xmitH),
        .xmit_dataH(xmit_dataH),
        .uart_REC_dataH(uart_rec_dataH),
        .uart_XMIT_dataH(uart_xmit_dataH),
        .xmit_doneH(xmit_doneH),
        .xmit_active(xmit_active),
        .rec_readyH(rec_readyH),
        .rec_busy(rec_busy),
        .rec_dataH(rec_dataH)
    ); */




    uart_ref sb (
        .sys_clk       (sys_clk),
        .sys_rst       (sys_rst),
        .load (sb_load),
        .exp_data (sb_expected),
        .check  (sb_check),
        .actual_data   (rec_dataH),
        .pass    (sb_pass),
        .fail   (sb_fail)
    );

   initial begin
        sys_clk = 0;
        forever #5 sys_clk = ~sys_clk; // 10ns period = 100MHz
    end
    
    task do_reset;
    begin
        sys_rst     = 0;
        xmitH       = 0;
        xmit_dataH  = 0;
        loopback_en = 0;
        rx_force    = 1; 
        sb_load     = 0;
        sb_check    = 0;
        #1000;
        sys_rst     = 1;
        #1000;
    end
    endtask

    task verify_scoreboard;
    begin
        @(negedge sys_clk);
        sb_check = 1'b1;
        @(negedge sys_clk);
        sb_check = 1'b0;
        
        if (sb_pass) pass_count = pass_count + 1;
        if (sb_fail) fail_count = fail_count + 1;
    end
    endtask


    task force_rx_frame(input [7:0] data, input valid_stop);
        integer bit_idx;
    begin
        // Start Bit (0)
        rx_force = 1'b0;
        #BIT_PERIOD;
        
        // Data Bits        
        for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
            rx_force = data[bit_idx];
            #BIT_PERIOD;
        end
        
        // Stop Bit (1 for valid, 0 for error)
        rx_force = valid_stop ? 1'b1 : 1'b0;
        #BIT_PERIOD;
        
        // Return to IDLE
        rx_force = 1'b1;
    end
    endtask

    initial begin
       
        $display("\n==================================================");
        $display("   STARTING UART VERIFICATION ");
        $display("==================================================\n");

        do_reset();
        
        // Case 2: TX Reset Check
        xmit_dataH = 8'hFF;
        xmitH = 1;
        #500;
        sys_rst = 0; // Async reset mid-operation
        #100;
        if (xmit_active == 0 && uart_xmit_dataH == 1) $display("[PASS] Case 2: TX Async Reset");
        else $display("[FAIL] Case 2: TX Async Reset");
        sys_rst = 1;
        xmitH = 0;
        #1000;

        //TX Reset check additional case 1 (START --> IDLE)
        xmit_dataH=8'hFF;
        xmitH=1;
        wait(xmit_active == 1);
        #(BIT_PERIOD/4);
        sys_rst=0;
        #1000
        if(xmit_active == 0 && uart_xmit_dataH ==1) $display("[PASS]: additional case 1");
        else $display("[FAIL]: additional case 1");
        sys_rst=1;
        xmitH=0;
        #1000;

        //TX Reset check additional case 2 (DATA --> IDLE)
        loopback_en=1;
        xmit_dataH=8'hCC;
        xmitH=1;
        wait(xmit_active ==1)
        @(negedge sys_clk);
        xmitH=0;
        #(BIT_PERIOD*4);
        sys_rst=0;
        #1000;
        if(xmit_active ==0 && uart_xmit_dataH ==1) $display("[PASS]: additional case 2");
        else $display("[FAIL]: additional case 2");
        sys_rst=1;
        loopback_en=0;
        #1000;

       // Case 7 and 8 continuous TX/RX (STOP --> START)
        loopback_en=1;
        @(negedge sys_clk);
        sb_expected=8'hAC;
        sb_load=1;
        @(negedge sys_clk);
        sb_load=0;
        
        xmit_dataH=8'hAC;
        xmitH=1;
        wait(xmit_active == 1);
        @(negedge sys_clk);
        xmit_dataH=8'h56;
        @(posedge rec_readyH);
        verify_scoreboard();

        @(negedge sys_clk);
        sb_expected=8'h56;
        sb_load=1;
        @(negedge sys_clk);
        sb_load=0;

        @(posedge rec_readyH);
        verify_scoreboard();
        @(negedge sys_clk);
        xmitH=0;

        wait(xmit_active == 0);
        $display("[PASS] continuous TX/RX for 2 Bytes of Data");
        #10000;
      //  loopback_en=0;
      //  #1000;


      
        //5 and 9: Loopback TX/RX Test
      //  loopback_en = 1; 
        
        // Load Scoreboard
        @(negedge sys_clk);
        sb_expected = 8'hA6;
        sb_load = 1;
        @(negedge sys_clk);
        sb_load = 0;

        // Transmit
        xmit_dataH = 8'hA6;
        xmitH = 1;
        wait(xmit_active == 1);
        @(negedge sys_clk);
        xmitH = 0;
        
        // Wait for loopback reception
        @(posedge rec_readyH);
        verify_scoreboard();
        $display("[INFO] Case 5 & 9 Completed.");
        
        // Case 6: Independent RX Check
        loopback_en = 0; // Disconnect loopback!
        #10000;
        
        // Load Scoreboard
        @(negedge sys_clk);
        sb_expected = 8'h3C;
        sb_load = 1;
        @(negedge sys_clk);
        sb_load = 0;
        fork
            force_rx_frame(8'h3C, 1'b1); // Thread 1
            begin
                @(posedge rec_readyH);   // Thread 2
                verify_scoreboard();
                $display("[INFO] Case 6 Completed.");
            end
        join
        $display("\n>> Running continous random tests.");
        loopback_en=1;
        for(i=0;i<100;i=i+1) begin
            random_data=$random;
            @(negedge sys_clk);
            sb_expected=random_data;
            sb_load=1;
            @(negedge sys_clk);
            sb_load=0;
                
            //Drive TX and RX continuously
            fork
                begin
                    wait(xmit_active==0);
                    xmit_dataH=random_data;
                    xmitH=1;

                    wait(xmit_active==1);
                    @(negedge sys_clk);
                    xmitH=0;
                    wait(xmit_active==0);
                end

                begin
                    @(posedge rec_readyH);
                    verify_scoreboard();
                end
            join

            #10000;
        end

        //Additional RX case for (START --> IDLE)
        loopback_en=0;

        rx_force=0;

        #(BIT_PERIOD/4);
        sys_rst=0;
        #1000;
        sys_rst=1;
        rx_force=1;
        #10000;
        if(rec_busy == 0) 
            $display("[PASS] RX successfully reset at START state ");
        else 
            $display("[FAIL] RX did not successfully reset at START state");



        $display("100 Random transactions completed");
       
        $display("\n>> RUNNING CORNER CASES (10-13)");
        
        loopback_en = 0; // Cut the wire! Force RX to listen to the testbench
        #10000;
        
        // Case 10: RX Start Glitch (Drive low for 3 ticks, ~78,000 ns)
        $display("-> Injecting Case 10: Start Glitch");
        rx_force = 0;
        #80000; 
        rx_force = 1;
        #1000000; 
        if (rec_busy == 0) $display("[PASS] Case 10: Glitch ignored safely.");
        else $display("[FAIL] Case 10: Receiver got stuck on a glitch!");


        // Case 12 & 13: Framing Error + Immediate Recovery
        $display("-> Injecting Case 12 & 13: Framing Error + Immediate Recovery");
        
        // 1. Tell Scoreboard to expect the VALID byte (0xBB)
        @(negedge sys_clk);
        sb_expected = 8'hBB;
        sb_load = 1;
        @(negedge sys_clk);
        sb_load = 0;
        
        // 2. Drive the line manually
        fork
            begin
                // Send BAD Frame (0x55 with Stop Bit = 0)
                force_rx_frame(8'h55, 1'b0); 
                
                // Immediately send GOOD Frame (0xBB with Stop Bit = 1) 
                // The Stop bit of the bad frame (0) acts as the Start bit of the good frame!
                force_rx_frame(8'hBB, 1'b1);
            end
            
            // 3. Listen for the pulse
            begin
                @(posedge rec_readyH);
                verify_scoreboard();
                $display("[INFO] Case 12 & 13 Completed.");
            end
        join
        $display("\n==================================================");
        $display("   FINAL VERIFICATION REPORT");
        $display("==================================================");
        $display("   PASSED DATA CHECKS : %0d", pass_count);
        $display("   FAILED DATA CHECKS : %0d", fail_count);
        $display("==================================================\n");
        $finish;
     end


endmodule

