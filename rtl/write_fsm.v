module write_fsm (
    input  wire        clk,
    input  wire        reset,
    input  wire        trigger,
    input  wire [31:0] destination_address,
    input  wire        read_done,

    // AXI-Lite Write Master interface
    output reg  [31:0] AWADDR,
    output reg         AWVALID,
    input  wire        AWREADY,
    output reg  [31:0] WDATA,
    output reg         WVALID,
    input  wire        WREADY,
    input  wire        BVALID,
    output reg         BREADY,

    // FIFO read interface
    input  wire [31:0] fifo_rd_data,
    output reg         fifo_rd_en,
    input  wire        fifo_empty,

    output reg         write_done
);

    // FSM states
    parameter IDLE       = 3'd0;
    parameter CHECK_FIFO = 3'd1;
    parameter SEND_AW    = 3'd2;
    parameter SEND_W     = 3'd3;
    parameter WAIT_B     = 3'd4;
    parameter DONE       = 3'd5;

    reg [2:0] state, next_state;
    reg [31:0] AWADDR_reg;
    reg [31:0] wdata_reg;   // captured FIFO word, held for SEND_W

    // ------------------------------------------------------------
    // State register
    // ------------------------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset)
            state <= IDLE;
        else
            state <= next_state;
    end

    // ------------------------------------------------------------
    // Next state logic
    // ------------------------------------------------------------
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (trigger)
                    next_state = CHECK_FIFO;
            end

            CHECK_FIFO: begin
                if (!fifo_empty)
                    next_state = SEND_AW;
                else if (fifo_empty && read_done)
                    next_state = DONE;
                // else: stay in CHECK_FIFO, waiting for more data
            end

            SEND_AW: begin
                if (AWVALID && AWREADY)
                    next_state = SEND_W;
            end

            SEND_W: begin
                if (WVALID && WREADY)
                    next_state = WAIT_B;
            end

            WAIT_B: begin
                if (BVALID && BREADY)
                    next_state = CHECK_FIFO;
            end

            DONE: begin
                next_state = DONE; // stays until reset
            end

            default: next_state = IDLE;
        endcase
    end

    // ------------------------------------------------------------
    // Datapath / output logic
    // ------------------------------------------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            AWADDR     <= 32'b0;
            AWVALID    <= 1'b0;
            WDATA      <= 32'b0;
            WVALID     <= 1'b0;
            BREADY     <= 1'b0;
            fifo_rd_en <= 1'b0;
            write_done <= 1'b0;
            AWADDR_reg <= 32'b0;
            wdata_reg  <= 32'b0;
        end
        else begin
            // default: de-assert pulse signal each cycle
            fifo_rd_en <= 1'b0;

            case (state)

                IDLE: begin
                    write_done <= 1'b0;
                    if (trigger) begin
                        AWADDR_reg <= destination_address;
                    end
                end

                CHECK_FIFO: begin
                    if (!fifo_empty) begin
                        // pop this cycle; fifo_rd_data will be valid next cycle
                        fifo_rd_en <= 1'b1;
                    end
                end

                SEND_AW: begin
                    // capture popped word (valid one cycle after fifo_rd_en pulse,
                    // i.e. on entry to SEND_AW)
                    wdata_reg <= fifo_rd_data;

                    AWADDR  <= AWADDR_reg;
                    AWVALID <= 1'b1;
                    if (AWVALID && AWREADY) begin
                        AWVALID <= 1'b0;
                    end
                end

                SEND_W: begin
                    WDATA  <= wdata_reg;
                    WVALID <= 1'b1;
                    if (WVALID && WREADY) begin
                        WVALID <= 1'b0;
                        BREADY <= 1'b1;
                    end
                end

                WAIT_B: begin
                    if (BVALID && BREADY) begin
                        BREADY     <= 1'b0;
                        AWADDR_reg <= AWADDR_reg + 4;
                    end
                end

                DONE: begin
                    write_done <= 1'b1;
                end

                default: ;
            endcase
        end
    end

endmodule
