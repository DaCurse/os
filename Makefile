all: run

bootloader/boot.bin: bootloader/boot.s
	nasm -fbin $< -o $@

bootloader/kernel.o: bootloader/kernel.s
	nasm -felf $< -o $@

.PHONY: target/os/release/libkernel.a
target/os/release/libkernel.a:
	cargo build --release

kernel.bin: bootloader/kernel.o target/os/release/libkernel.a
	ld -m elf_i386 -Ttext 0x1000 -o $@ $^ --oformat binary

os.bin:	bootloader/boot.bin kernel.bin
	cat $^ > $@


.PHONY: run clean
run: os.bin
	qemu-system-i386 -fda os.bin

clean:
	rm *.bin
	rm bootloader/*.o