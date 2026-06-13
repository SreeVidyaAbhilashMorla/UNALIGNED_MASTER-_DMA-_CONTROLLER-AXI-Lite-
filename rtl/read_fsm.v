module read_fsm (
    input  wire        clk,
    input  wire        reset,
    input  wire        trigger,
    input  wire [4:0]  length,            // bytes to transfer
    input  wire [31:0] source_address,

    // AXI-Lite Read Master interface
    output reg  [31:0] ARADDR,
    output reg         ARVALID,
    input  wire        ARREADY,
    input  wire [31:0] RDATA,
    input  wire        RVALID,
    output reg         RREADY,

    // FIFO write interface
    output reg  [31:0] fifo_wr_data,
    output reg         fifo_wr_en,
    input  wire        fifo_full,

    output reg         read_done
);

    // FSM states
    parameter IDLE    = 3'd0;
    parameter SEND_AR = 3'd1;
    parameter WAIT_R  = 3'd2;
    parameter SHIFT   = 3'd3;
    parameter DONE    = 3'd4;
    reg [2:0] state, next_state;

    // Internal registers
    reg [63:0] shift_reg;
    reg [6:0]  valid_bits;     // 0-64
    reg [4:0]  bytes_to_fetch;
    reg [1:0]  offset;
    reg        first_word;

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
                    next_state = SEND_AR;
            end

            SEND_AR: begin
                if (ARVALID && ARREADY)
                    next_state = WAIT_R;
            end

            WAIT_R: begin
                if (RVALID && RREADY)
                    next_state = SHIFT;
            end

            SHIFT: begin
                // Decision logic (combinational preview using current regs;
                // actual updates happen in sequential block below)
                if (bytes_to_fetch == 0)
                    next_state = DONE;
                else if (bytes_to_fetch >= 4 && valid_bits >= 32)
                    next_state = SHIFT; // stay one cycle to allow another push if valid_bits=64
                else if (bytes_to_fetch < 4 && valid_bits >= (bytes_to_fetch << 3))
                    next_state = DONE;
                else
                    next_state = SEND_AR;
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
            ARADDR         <= 32'b0;
            ARVALID        <= 1'b0;
            RREADY         <= 1'b0;
            fifo_wr_data   <= 32'b0;
            fifo_wr_en     <= 1'b0;
            read_done      <= 1'b0;
            shift_reg      <= 64'b0;
            valid_bits     <= 7'b0;
            bytes_to_fetch <= 5'b0;
            offset         <= 2'b0;
            first_word     <= 1'b1;
        end
        else begin
            // default: de-assert pulse signals each cycle
            fifo_wr_en <= 1'b0;

            case (state)

                IDLE: begin
                    read_done <= 1'b0;
                    if (trigger) begin
                        offset         <= source_address[1:0];
                        ARADDR         <= {source_address[31:2], 2'b00}; // word-align down
                        bytes_to_fetch <= length;
                        valid_bits     <= 7'b0;
                        shift_reg      <= 64'b0;
                        first_word     <= 1'b1;
                    end
                end

                SEND_AR: begin
                    ARVALID <= 1'b1;
                    if (ARVALID && ARREADY) begin
                        ARVALID <= 1'b0;
                        RREADY  <= 1'b1;
                    end
                end

                WAIT_R: begin
                    if (RVALID && RREADY) begin
                        RREADY <= 1'b0;

                        if (first_word) begin
                            // discard `offset` bytes from MSB side
                            shift_reg  <= {(RDATA << (offset*8)), 32'b0};
                            valid_bits <= 32 - (offset * 8);
                            first_word <= 1'b0;
                        end
                        else begin
                            // append new word right after current valid bits
                            shift_reg  <= shift_reg | ({32'b0, RDATA} << (32 - valid_bits));
                            valid_bits <= valid_bits + 32;
                        end
                    end
                end

                SHIFT: begin
                    if (bytes_to_fetch == 0) begin
                        // nothing to do, will move to DONE
                    end
                    else if (bytes_to_fetch >= 4 && valid_bits >= 32) begin
                        // PUSH
                        fifo_wr_data <= shift_reg[63:32];
                        fifo_wr_en   <= 1'b1;
                        shift_reg    <= shift_reg << 32;
                        valid_bits   <= valid_bits - 32;
                        bytes_to_fetch <= bytes_to_fetch - 4;
                    end
                    else if (bytes_to_fetch < 4 && valid_bits >= (bytes_to_fetch << 3)) begin
                        // DROP leftover, finish
                        bytes_to_fetch <= 0;
                    end
                    else begin
                        // need more data -> prepare next AR
                        ARADDR <= ARADDR + 4;
                    end
                end

                DONE: begin
                    read_done <= 1'b1;
                end

                default: ;
            endcase
        end
    end

endmodule
