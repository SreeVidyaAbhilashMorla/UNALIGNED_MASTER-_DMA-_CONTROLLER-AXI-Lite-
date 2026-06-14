`timescale 1ns / 1ps

module tb_write_fsm;

    reg clk;
    reg reset;
    reg trigger;
    reg [31:0] destination_address;
    reg read_done;

    wire [31:0] AWADDR;
    wire        AWVALID;
    reg         AWREADY;
    wire [31:0] WDATA;
    wire        WVALID;
    reg         WREADY;
    reg         BVALID;
    wire        BREADY;

    wire [31:0] fifo_rd_data;
    wire        fifo_rd_en;
    wire        fifo_empty;
    reg         fifo_wr_en;
    reg [31:0]  fifo_wr_data;
    wire        fifo_full;

    wire write_done;

    // -------------------------------------------------
    // DUT instances
    // -------------------------------------------------
    write_fsm uut_write (
        .clk(clk),
        .reset(reset),
        .trigger(trigger),
        .destination_address(destination_address),
        .read_done(read_done),
        .AWADDR(AWADDR),
        .AWVALID(AWVALID),
        .AWREADY(AWREADY),
        .WDATA(WDATA),
        .WVALID(WVALID),
        .WREADY(WREADY),
        .BVALID(BVALID),
        .BREADY(BREADY),
        .fifo_rd_data(fifo_rd_data),
        .fifo_rd_en(fifo_rd_en),
        .fifo_empty(fifo_empty),
        .write_done(write_done)
    );

    sync_fifo uut_fifo (
        .clk(clk),
        .fifo_reset(reset),
        .fifo_wr_en(fifo_wr_en),
        .fifo_rd_en(fifo_rd_en),
        .fifo_wr_data(fifo_wr_data),
        .fifo_rd_data(fifo_rd_data),
        .fifo_full(fifo_full),
        .fifo_empty(fifo_empty)
    );

    // -------------------------------------------------
    // Clock
    // -------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------
    // Mock destination memory (AXI-Lite write slave)
    // -------------------------------------------------
    reg [31:0] dest_mem [0:15]; // base = 0x2000, index = (addr-0x2000)>>2
    integer i;

    // AWREADY: ready one cycle after AWVALID
    always @(posedge clk or posedge reset) begin
        if (reset)
            AWREADY <= 1'b0;
        else
            AWREADY <= AWVALID && !AWREADY ? 1'b1 : 1'b0;
    end

    // Simpler: always ready
    // (overriding above complexity - keep AWREADY high whenever AWVALID asserted)
    always @(*) begin
        AWREADY = AWVALID;
    end

    // WREADY: always ready
    always @(*) begin
        WREADY = WVALID;
    end

    // Capture write address+data on handshake, perform memory write
    reg [31:0] awaddr_captured;
    reg        aw_done;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            aw_done <= 1'b0;
            awaddr_captured <= 32'b0;
        end
        else begin
            if (AWVALID && AWREADY) begin
                awaddr_captured <= AWADDR;
                aw_done <= 1'b1;
            end
            if (WVALID && WREADY && aw_done) begin
                dest_mem[(awaddr_captured - 32'h2000) >> 2] <= WDATA;
                aw_done <= 1'b0;
            end
        end
    end

    // BVALID: assert one cycle after W handshake
    reg w_handshake_d;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            w_handshake_d <= 1'b0;
            BVALID <= 1'b0;
        end
        else begin
            w_handshake_d <= (WVALID && WREADY);
            if (w_handshake_d)
                BVALID <= 1'b1;
            else if (BVALID && BREADY)
                BVALID <= 1'b0;
        end
    end

    // -------------------------------------------------
    // Stimulus
    // -------------------------------------------------
    initial begin
        reset = 1;
        trigger = 0;
        destination_address = 0;
        read_done = 0;
        fifo_wr_en = 0;
        fifo_wr_data = 0;

        for (i = 0; i < 16; i = i + 1)
            dest_mem[i] = 32'hDEADDEAD;

        repeat (3) @(posedge clk);
        reset = 0;

        // Preload FIFO with Example 1's expected words
        @(posedge clk);
        fifo_wr_en   = 1;
        fifo_wr_data = 32'h3344AABB;
        @(posedge clk);
        fifo_wr_data = 32'hCCDDEEFF;
        @(posedge clk);
        fifo_wr_en   = 0;

        // Start write transfer
        destination_address = 32'h2000;
        read_done = 1;  // emulate: read side already finished pushing these 2 words
        trigger   = 1;
        @(posedge clk);
        trigger   = 0;

        // Wait for write_done
        wait (write_done == 1'b1);
        @(posedge clk);

        $display("---------------------------------------------------");
        $display("write_done = %b", write_done);
        $display("dest_mem[0x2000] = %h (expected 3344aabb)", dest_mem[0]);
        $display("dest_mem[0x2004] = %h (expected ccddeeff)", dest_mem[1]);
        $display("---------------------------------------------------");

        repeat (5) @(posedge clk);
        $finish;
    end

    // -------------------------------------------------
    // Waveform dump
    // -------------------------------------------------
    initial begin
        $dumpfile("tb_write_fsm.vcd");
        $dumpvars(0, tb_write_fsm);
    end

endmodule
