`timescale 1ns / 1ps

module tb_dma_top;

    reg clk;
    reg reset;
    reg trigger;
    reg [4:0]  length;
    reg [31:0] source_address;
    reg [31:0] destination_address;
    wire       done;

    // AXI-Lite Read interface
    wire [31:0] ARADDR;
    wire        ARVALID;
    reg         ARREADY;
    reg  [31:0] RDATA;
    reg         RVALID;
    wire        RREADY;

    // AXI-Lite Write interface
    wire [31:0] AWADDR;
    wire        AWVALID;
    reg         AWREADY;
    wire [31:0] WDATA;
    wire        WVALID;
    reg         WREADY;
    reg         BVALID;
    wire        BREADY;

    // -------------------------------------------------
    // DUT
    // -------------------------------------------------
    Master_DMA_Controller uut (
        .clk(clk),
        .reset(reset),
        .trigger(trigger),
        .length(length),
        .source_address(source_address),
        .destination_address(destination_address),
        .done(done),
        .ARADDR(ARADDR),
        .ARVALID(ARVALID),
        .ARREADY(ARREADY),
        .RDATA(RDATA),
        .RVALID(RVALID),
        .RREADY(RREADY),
        .AWADDR(AWADDR),
        .AWVALID(AWVALID),
        .AWREADY(AWREADY),
        .WDATA(WDATA),
        .WVALID(WVALID),
        .WREADY(WREADY),
        .BVALID(BVALID),
        .BREADY(BREADY)
    );

    // -------------------------------------------------
    // Clock
    // -------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------
    // Mock source memory (AXI-Lite read slave), base = 0x1000
    // -------------------------------------------------
    reg [31:0] src_mem [0:15];

    always @(*) ARREADY = ARVALID;

    reg [31:0] araddr_captured;
    reg        ar_handshake_d;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            ar_handshake_d  <= 1'b0;
            RVALID          <= 1'b0;
            RDATA           <= 32'b0;
            araddr_captured <= 32'b0;
        end
        else begin
            if (ARVALID && ARREADY)
                araddr_captured <= ARADDR;

            ar_handshake_d <= (ARVALID && ARREADY);

            if (ar_handshake_d) begin
                RVALID <= 1'b1;
                RDATA  <= src_mem[(araddr_captured - 32'h1000) >> 2];
            end
            else if (RVALID && RREADY) begin
                RVALID <= 1'b0;
            end
        end
    end

    // -------------------------------------------------
    // Mock destination memory (AXI-Lite write slave)
    // -------------------------------------------------
    reg [31:0] dst_mem [0:31];

    always @(*) AWREADY = AWVALID;
    always @(*) WREADY  = WVALID;

    reg [31:0] awaddr_captured;
    reg        aw_done;
    reg [31:0] dst_base;

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
                dst_mem[(awaddr_captured - dst_base) >> 2] <= WDATA;
                aw_done <= 1'b0;
            end
        end
    end

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
    integer i;
    initial begin
        reset = 1;
        trigger = 0;
        length = 0;
        source_address = 0;
        destination_address = 0;
        dst_base = 0;

        for (i = 0; i < 32; i = i + 1)
            dst_mem[i] = 32'hDEADDEAD;

        repeat (3) @(posedge clk);
        reset = 0;
        @(posedge clk);

        // =================================================
        // EXAMPLE 1: source_address=0x1002, length=10, dest=0x2000
        // Expected: dst_mem[0x2000]=3344AABB, dst_mem[0x2004]=CCDDEEFF
        // =================================================
        src_mem[0] = 32'h11223344; // 0x1000
        src_mem[1] = 32'hAABBCCDD; // 0x1004
        src_mem[2] = 32'hEEFF0011; // 0x1008
        src_mem[3] = 32'h22334455; // 0x100C

        dst_base = 32'h2000;
        source_address      = 32'h1002;
        destination_address = 32'h2000;
        length              = 5'd10;

        @(posedge clk);
        trigger = 1;
        @(posedge clk);
        trigger = 0;

        i = 0;
        while (i < 200 && !done) begin
            @(posedge clk);
            i = i + 1;
        end

        $display("====================================================");
        $display("EXAMPLE 1 RESULT (source=0x1002, length=10)");
        $display("dst_mem[0x2000] = %h (expected 3344aabb)", dst_mem[0]);
        $display("dst_mem[0x2004] = %h (expected ccddeeff)", dst_mem[1]);
        $display("done = %b", done);
        $display("====================================================");

        // -------- reset between transfers --------
        @(posedge clk);
        reset = 1;
        repeat (3) @(posedge clk);
        reset = 0;
        @(posedge clk);

        // =================================================
        // EXAMPLE 2: source_address=0x1011, length=9, dest=0x3000
        // Expected: dst_mem[0x3000]=ADBEEF11, dst_mem[0x3004]=22334455
        // =================================================
        src_mem[4] = 32'hDEADBEEF; // 0x1010
        src_mem[5] = 32'h11223344; // 0x1014
        src_mem[6] = 32'h55667788; // 0x1018

        dst_base = 32'h3000;
        source_address      = 32'h1011;
        destination_address = 32'h3000;
        length              = 5'd9;

        @(posedge clk);
        trigger = 1;
        @(posedge clk);
        trigger = 0;

        i = 0;
        while (i < 200 && !done) begin
            @(posedge clk);
            i = i + 1;
        end

        $display("====================================================");
        $display("EXAMPLE 2 RESULT (source=0x1011, length=9)");
        $display("dst_mem[0x3000] = %h (expected adbeef11)", dst_mem[(32'h3000-32'h3000)>>2]);
        $display("dst_mem[0x3004] = %h (expected 22334455)", dst_mem[(32'h3004-32'h3000)>>2]);
        $display("done = %b", done);
        $display("====================================================");

        repeat (5) @(posedge clk);
        $finish;
    end

    // -------------------------------------------------
    // Waveform dump
    // -------------------------------------------------
    initial begin
        $dumpfile("tb_dma_top.vcd");
        $dumpvars(0, tb_dma_top);
    end

endmodule
