# Makefile for building a two-stage bootloader and linking it with the kernel

# Output files
STAGE1_BIN = bootloader/stage1.bin
STAGE2_BIN = bootloader/stage2.bin
KERNEL_OBJ = bootloader/kernel.o
KERNEL_LIB = target/os/release/libkernel.a
KERNEL_BIN = kernel.bin
OS_BIN = os.bin

# Assembly source files
STAGE1_SRC = bootloader/stage1.s
STAGE2_SRC = bootloader/stage2.s
KERNEL_SRC = bootloader/kernel.s

# Build everything
all: run

# Build Stage 1 Bootloader
$(STAGE1_BIN): $(STAGE1_SRC)
	nasm -fbin $< -o $@

# Build Stage 2 Bootloader
$(STAGE2_BIN): $(STAGE2_SRC)
	nasm -fbin $< -o $@

# Compile the kernel object file
$(KERNEL_OBJ): $(KERNEL_SRC)
	nasm -felf64 $< -o $@

# Build the Rust kernel library
.PHONY: $(KERNEL_LIB)
$(KERNEL_LIB):
	cargo build --release

# Link the kernel binary
$(KERNEL_BIN): $(KERNEL_OBJ) $(KERNEL_LIB)
	ld -m elf_x86_64 -Ttext 0x2000 -o $@ $^ --oformat binary

# Combine Stage 1, Stage 2, and Kernel into a single bootable image
$(OS_BIN): $(STAGE1_BIN) $(STAGE2_BIN) $(KERNEL_BIN)
	cat $(STAGE1_BIN) $(STAGE2_BIN) $(KERNEL_BIN) > $@

# Run the OS using QEMU
.PHONY: run
run: $(OS_BIN)
	qemu-system-x86_64 -fda $(OS_BIN)

# Clean up build artifacts
.PHONY: clean
clean:
	rm -f $(OS_BIN) $(STAGE1_BIN) $(STAGE2_BIN) $(KERNEL_BIN)
	rm -f $(KERNEL_OBJ)
