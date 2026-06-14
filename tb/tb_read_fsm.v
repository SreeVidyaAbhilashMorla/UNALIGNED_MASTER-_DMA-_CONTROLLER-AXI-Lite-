`timescale 1ns / 1ps

module tb_read_fsm;

    reg clk;
    reg reset;
    reg trigger;
    reg [4:0] length;
    reg [31:0] source_address;

    wire [31:0] ARADDR;
    wire        ARVALID;
    reg         ARREADY;
    reg  [31:0] RDATA;
    reg         RVALID;
    wire        RREADY;

    wire [31:0] fifo_wr_data;
    wire        fifo_wr_en;
    wire        fifo_full;
    wire        fifo_empty;
    wire [31:0] fifo_rd_data;
    wire        read_done;

    reg         fifo_rd_en;

    // -------------------------------------------------
    // Mock source memory (word-addressable, 4-byte aligned)
    // Example 1 contents
    // -------------------------------------------------
    reg [31:0] mem [0:15];

    initial begin
        mem[0] = 32'h11223344; // addr 0x1000
        mem[1] = 32'hAABBCCDD; // addr 0x1004
        mem[2] = 32'hEEFF0011; // addr 0x1008
        mem[3] = 32'h22334455; // addr 0x100C
    end

    // -------------------------------------------------
    // DUT instances
    // -------------------------------------------------
    read_fsm uut_read (
        .clk(clk),
        .reset(reset),
        .trigger(trigger),
        .length(length),
        .source_address(source_address),
        .ARADDR(ARADDR),
        .ARVALID(ARVALID),
        .ARREADY(ARREADY),
        .RDATA(RDATA),
        .RVALID(RVALID),
        .RREADY(RREADY),
        .fifo_wr_data(fifo_wr_data),
        .fifo_wr_en(fifo_wr_en),
        .fifo_full(fifo_full),
        .read_done(read_done)
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
    always #5 clk = ~clk; // 100MHz, 10ns period

    // -------------------------------------------------
    // Mock AXI-Lite slave (source memory) behavior
    // -------------------------------------------------

    // ARREADY: always ready one cycle after ARVALID asserted
    always @(posedge clk or posedge reset) begin
        if (reset)
            ARREADY <= 1'b0;
        else
            ARREADY <= ARVALID; // simple 1-cycle latency slave
    end

    // RVALID + RDATA: one cycle after AR handshake completes
    reg ar_handshake_d;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            ar_handshake_d <= 1'b0;
            RVALID <= 1'b0;
            RDATA  <= 32'b0;
        end
        else begin
            ar_handshake_d <= (ARVALID && ARREADY);
            if (ar_handshake_d) begin
                RVALID <= 1'b1;
                RDATA  <= mem[(ARADDR_captured - 32'h1000) >> 2];
            end
            else if (RVALID && RREADY) begin
                RVALID <= 1'b0;
            end
        end
    end

    // Capture ARADDR at the moment of AR handshake (since ARADDR may change next cycle)
    reg [31:0] ARADDR_captured;
    always @(posedge clk) begin
        if (ARVALID && ARREADY)
            ARADDR_captured <= ARADDR;
    end

    // -------------------------------------------------
    // FIFO read side - just monitor, pop everything after read_done
    // -------------------------------------------------
    initial fifo_rd_en = 1'b0;

    // -------------------------------------------------
    // Stimulus
    // -------------------------------------------------
    initial begin
        reset = 1;
        trigger = 0;
        length = 0;
        source_address = 0;

        repeat (3) @(posedge clk);
        reset = 0;

        // ---------------- Example 1 ----------------
        @(posedge clk);
        source_address = 32'h1002;
        length         = 5'd10;
        trigger        = 1;
        @(posedge clk);
        trigger        = 0;

        // Wait for read_done
        wait (read_done == 1'b1);
        @(posedge clk);

        $display("---------------------------------------------------");
        $display("Example 1 finished. read_done = %b", read_done);
        $display("---------------------------------------------------");

        // Pop FIFO contents and display
        fifo_rd_en = 1;
        @(posedge clk);
        $display("FIFO[0] = %h (expected 3344AABB)", fifo_rd_data);
        @(posedge clk);
        $display("FIFO[1] = %h (expected CCDDEEFF)", fifo_rd_data);
        fifo_rd_en = 0;

        @(posedge clk);
        $display("fifo_empty = %b (expected 1)", fifo_empty);

        repeat (5) @(posedge clk);
        $finish;
    end

    // -------------------------------------------------
    // Waveform dump
    // -------------------------------------------------
    initial begin
        $dumpfile("tb_read_fsm.vcd");
        $dumpvars(0, tb_read_fsm);
    end

endmodule
