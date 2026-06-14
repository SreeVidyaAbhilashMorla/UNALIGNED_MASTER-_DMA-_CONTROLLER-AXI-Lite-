# Unaligned DMA Controller (AXI-Lite)
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


## Data flow
 1. The Read FSM fetches data from the source memory using AXI-Lite read transactions.
 2. Valid bytes are assembled into 32-bit words and stored in the synchronous FIFO.
 3. The Write FSM retrieves complete words from the FIFO.
 4. The Write FSM writes aligned 32-bit words to the destination memory.
 5. The DMA controller asserts the done signal when the transfer is complete.

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

  ## STATE DIAGRAM

  <img width="3080" height="2600" alt="read_fsm_state_diagram_bw" src="https://github.com/user-attachments/assets/a96703df-eab4-4415-9d0f-a38810a9e27e" />
 ## RTL Implementation
 * Implemented in  [read_fsm.v](rtl/read_fsm.v)

   ## WRITE FSM
   ### Overview
   
   The Write FSM acts as an AXI-Lite master on the write side. It continuously pops complete 32-bit words from the FIFO and writes them to sequential, word-aligned destination addresses using the full AXI-Lite write handshake (Address, Data, and Response channels).

### Write FSM — State Description

### IDLE

* Waits for trigger.
* On trigger, latches destination_address into an internal address register (AWADDR_reg) that will be used and incremented for subsequent writes.

### CHECK_FIFO 

* Checks the FIFO status:
  
* If fifo_empty is 0 → a word is available; pulses fifo_rd_en for one cycle to pop it, and moves to SEND_AW.
* If fifo_empty is 1 and read_done is 1 → no more words will ever arrive; transfer is complete, moves to DONE.
* If fifo_empty is 1 and read_done is 0 → Read FSM is still working; stays in CHECK_FIFO waiting for more data.

### SEND_AW

* Captures the popped FIFO word (wdata_reg <= fifo_rd_data, valid one cycle after the pop).
*  Drives AWADDR = AWADDR_reg and AWVALID = 1, waiting for AWREADY.
*  Once both are high (AW handshake complete), moves to SEND_W.

### SEND_W

* Drives WDATA = wdata_reg and WVALID = 1, waiting for WREADY.
* Once both are high (W handshake complete), asserts BREADY = 1 and moves to WAIT_B.

### WAIT_B

* Waits for BVALID (write response from slave).
* Once BVALID and BREADY are both high, increments AWADDR_reg by 4 (next destination word) and returns to CHECK_FIFO to process the next word.

### DONE

* Asserts write_done = 1 and remains here until reset, signaling the entire write transfer is complete.

  ## State Diagram
  <img width="1371" height="1148" alt="write_fsm_blockdiagram" src="https://github.com/user-attachments/assets/4883f490-e5f1-40ad-b804-00a8b8a77827" />

## RTL Implementation

* Implemented in  [write_fsm.v](rtl/write_fsm.v)

  ## Sync FIFO

  ### Overview

  A 16-deep, 32-bit synchronous FIFO that decouples the Read FSM and Write FSM, operating on a single shared clock domain (no clock-domain-crossing logic needed).

 ### Responsibilities
### 1.Buffering

* Temporarily holds complete 32-bit words produced by the Read FSM until the Write FSM is ready to consume them.
  
### 2. Write Operation

* When fifo_wr_en is high and fifo_full is low, fifo_wr_data is stored at fifo_wr_ptr, the pointer increments, and fifo_count increases by 1.
  
### 3. Read Operation

* When fifo_rd_en is high and fifo_empty is low, the word at fifo_rd_ptr is presented on fifo_rd_data, the pointer increments, and fifo_count decreases by 1.
  
### 4. Simultaneous Read/Write

* If both a valid write and a valid read occur in the same cycle, both pointers advance but fifo_count remains unchanged (one word in, one word out).
  
### 5. Status Flags

* fifo_full = (fifo_count == 16) — Read FSM should not push when full
* fifo_empty = (fifo_count == 0) — Write FSM should not pop when empty

### 6. Pointer Wraparound

* fifo_wr_ptr and fifo_rd_ptr are 4-bit registers; incrementing past 15 wraps to 0 automatically via natural binary overflow — no explicit wrap logic needed.
### Reset Behavior
* On fifo_reset, both pointers and fifo_count are cleared to 0, effectively emptying the FIFO.

  ## RTL Implementation

   * Implemented in  [sync_fifo.v](rtl/sync_fifo.v)
