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
