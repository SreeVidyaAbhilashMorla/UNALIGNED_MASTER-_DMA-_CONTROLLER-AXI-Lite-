module sync_fifo (
    input  wire        clk,
    input  wire        fifo_reset,
    input  wire        fifo_wr_en,
    input  wire        fifo_rd_en,
    input  wire [31:0] fifo_wr_data,
    output reg  [31:0] fifo_rd_data,
    output wire        fifo_full,
    output wire        fifo_empty
);

    reg [31:0] fifo [15:0]; // 16-DEEP 32BIT FIFO
    reg [3:0]  fifo_wr_ptr, fifo_rd_ptr;
    reg [4:0]  fifo_count;

    assign fifo_full  = (fifo_count == 16);
    assign fifo_empty = (fifo_count == 0);

    always @(posedge clk or posedge fifo_reset) begin
        if (fifo_reset) begin
            fifo_wr_ptr <= 0;
            fifo_rd_ptr <= 0;
            fifo_count  <= 0;
        end
        else begin
            case ({(fifo_wr_en && !fifo_full), (fifo_rd_en && !fifo_empty)})
                2'b10: begin // write only
                    fifo[fifo_wr_ptr] <= fifo_wr_data;
                    fifo_wr_ptr <= fifo_wr_ptr + 1;
                    fifo_count  <= fifo_count + 1;
                end
                2'b01: begin // read only
                    fifo_rd_data <= fifo[fifo_rd_ptr];
                    fifo_rd_ptr  <= fifo_rd_ptr + 1;
                    fifo_count   <= fifo_count - 1;
                end
                2'b11: begin // simultaneous read+write
                    fifo[fifo_wr_ptr] <= fifo_wr_data;
                    fifo_rd_data <= fifo[fifo_rd_ptr];
                    fifo_wr_ptr  <= fifo_wr_ptr + 1;
                    fifo_rd_ptr  <= fifo_rd_ptr + 1;
                    // count unchanged
                end
                default: fifo_count<=fifo_count;// no operation
            endcase
        end
    end

endmodule
