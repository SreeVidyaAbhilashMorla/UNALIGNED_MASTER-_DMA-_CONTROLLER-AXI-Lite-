module Master_DMA_Controller (
    input  wire        clk,
    input  wire        reset,
    input  wire        trigger,
    input  wire [4:0]  length,
    input  wire [31:0] source_address,
    input  wire [31:0] destination_address,
    output wire        done,

    // AXI-Lite Read Master interface
    output wire [31:0] ARADDR,
    output wire        ARVALID,
    input  wire        ARREADY,
    input  wire [31:0] RDATA,
    input  wire        RVALID,
    output wire        RREADY,

    // AXI-Lite Write Master interface
    output wire [31:0] AWADDR,
    output wire        AWVALID,
    input  wire        AWREADY,
    output wire [31:0] WDATA,
    output wire        WVALID,
    input  wire        WREADY,
    input  wire        BVALID,
    output wire        BREADY
);

    wire        read_done;
    wire        write_done;

    wire [31:0] fifo_wr_data;
    wire        fifo_wr_en;
    wire [31:0] fifo_rd_data;
    wire        fifo_rd_en;
    wire        fifo_full;
    wire        fifo_empty;

    assign done = write_done;

    read_fsm u_read_fsm (
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

    sync_fifo u_sync_fifo (
        .clk(clk),
        .fifo_reset(reset),
        .fifo_wr_en(fifo_wr_en),
        .fifo_rd_en(fifo_rd_en),
        .fifo_wr_data(fifo_wr_data),
        .fifo_rd_data(fifo_rd_data),
        .fifo_full(fifo_full),
        .fifo_empty(fifo_empty)
    );

    write_fsm u_write_fsm (
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

endmodule
