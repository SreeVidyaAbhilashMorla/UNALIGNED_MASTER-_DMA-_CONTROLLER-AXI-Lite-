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
