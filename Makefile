# Makefile for building a two-stage bootloader and linking it with the kernel

# Output files
STAGE1_BIN = bootloader/stage1.bin
STAGE2_BIN = bootloader/stage2.bin
KERNEL_OBJ = bootloader/kernel.o
KERNEL_LIB = target/os/release/libkernel.a
KERNEL_BIN = kernel.bin
OS_IMG = os.img

# Assembly source files
STAGE1_SRC = bootloader/stage1.s
STAGE2_SRC = bootloader/stage2.s
KERNEL_SRC = bootloader/kernel.s

# Disk image properties
DISK_IMG_SIZE = 64MiB
STAGE2_SECTORS = 8
BOOT_PART_SIZE = 32MiB

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
$(OS_IMG): $(STAGE1_BIN) $(STAGE2_BIN) $(KERNEL_BIN)
	fallocate -l $(DISK_IMG_SIZE) $@
	dd if=$(STAGE1_BIN) of=$@ bs=512 count=1 conv=notrunc
	dd if=$(STAGE2_BIN) of=$@ bs=512 count=$(STAGE2_SECTORS) seek=1 conv=notrunc

	parted --script $@ \
		mkpart primary fat16 2048s $(BOOT_PART_SIZE) \
		mkpart primary ext2 $(BOOT_PART_SIZE) 100% \
		set 1 boot on

	LOOP_DEV=$$(sudo losetup --show --partscan --find $@) && \
		sudo mkfs.fat -F 16 "$${LOOP_DEV}p1" && \
		sudo mkfs.ext2 "$${LOOP_DEV}p2" && \
		sudo mount "$${LOOP_DEV}p1" /mnt && \
		sudo cp -v $(KERNEL_BIN) /mnt && \
		sudo ls -la /mnt && \
		sudo umount /mnt && \
		sudo losetup -d "$$LOOP_DEV"

# Run the OS using QEMU
.PHONY: run
run: $(OS_IMG)
	qemu-system-x86_64 -hda $(OS_IMG)

# Clean up build artifacts
.PHONY: clean
clean:
	rm -f $(OS_IMG) $(STAGE1_BIN) $(STAGE2_BIN) $(KERNEL_BIN)
	rm -f $(KERNEL_OBJ)
