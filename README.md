# UNALIGNED MASTER DMA CONTROLLER(AXI-Lite)-
A Verilog-based DMA controller that performs autonomous memory-to-memory transfers via AXI-Lite, supporting unaligned source addresses and arbitrary transfer lengths (not necessarily multiples of 4 bytes).

## Key Features
- **AXI-Lite Master** interface for both read and write channels
- Supports **unaligned source addresses** — reads start at any byte offset, not just word boundaries
- Handles **arbitrary byte-length transfers** (e.g., 5, 7, 9, 10 bytes)
- **Aligned destination writes** — only complete 32-bit words are written to memory
- **16-depth, 32-bit synchronous FIFO** decouples read and write operations
- **Dual FSM architecture** — independent Read FSM and Write FSM operating in parallel
- Drops trailing incomplete words (< 32 bits) at end of transfer, per spec
- Asserts done signal upon transfer completion
## Block Diagram
The DMA controller reads unaligned data from source memory through the Read FSM, buffers data in a 16×32-bit synchronous FIFO, and writes aligned 32-bit words to destination memory using the Write FSM.

<img width="1672" height="941" alt="dma_blockdiagram" src="https://github.com/user-attachments/assets/6beeac34-f27a-4738-bb6e-0ee978e6360e" />

## READ FSM
### Overview

The Read FSM acts as an AXI-Lite master that reads data from a (possibly unaligned) source address in memory, extracts only the required bytes, reassembles them into full 32-bit words using a shift register, and pushes complete words into the FIFO.

### Read FSM — State Description

### State0-IDLE
* The FSM waits here for trigger.
* On trigger, it latches the inputs: computes offset = source_address[1:0].
*  Word-aligns ARADDR (rounds source_address down to a multiple of 4).
*  Initializes bytes_to_fetch = length
*   Resets valid_bits and shift_reg to zero.
  
### State1-SEND_AR
* The FSM asserts ARADDR and ARVALID to request a 32-bit word from source memory.
* It waits here until the slave responds with ARREADY.
*  Once both ARVALID and ARREADY are high (handshake complete), it moves to WAIT_R.

### State2-WAIT_R
* The FSM asserts RREADY to indicate it can accept data.
* It waits until the slave responds with RVALID.
* Once both are high, RDATA is captured into the shift register, and the FSM moves to SHIFT.
  
### State3-SHIFT
* This is the core processing state.
*  Based on the captured word: If it's the first word, the leading offset bytes are discarded and valid_bits is set accordingly.
* Otherwise, the new word is appended into the shift register right after the existing valid bits, and valid_bits = valid_bits+32.
* Then a decision is made:
* If valid_bits >= 32 and bytes_to_fetch >= 4 → push the top 32 bits to the FIFO, reduce valid_bits by 32 and bytes_to_fetch by 4.
* If bytes_to_fetch == 0 → transfer is complete, move to DONE.
* If bytes_to_fetch < 4 and enough leftover bits are available → drop the remaining bytes (incomplete word) and move to DONE.
* Otherwise → not enough data yet, increment ARADDR by 4 and go back to SEND_AR to fetch the next word.
  
### State4-DONE
* The FSM asserts read_done = 1 and remains here until reset is applied (preparing for the next transfer).

  ### STATE DIAGRAM

  <img width="3080" height="2600" alt="read_fsm_state_diagram_bw" src="https://github.com/user-attachments/assets/a96703df-eab4-4415-9d0f-a38810a9e27e" />
 ### RTL Implementation
 * Implemented in  [read_fsm.v](rtl/read_fsm.v)
