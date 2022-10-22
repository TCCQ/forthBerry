AS=aarch64-linux-gnu-as
OC=aarch64-linux-gnu-objcopy
ASFLAGS=-g
LFLAGS=-g
LINKER=aarch64-linux-gnu-ld

sd.img:kernel.img
	rm -rf sd.img
	mkdir -p mnt
	truncate -s 1G sd.img
	mkfs.fat sd.img	
	sudo mount -o loop sd.img mnt
	sudo cp drive/* kernel.img -t mnt
	echo -e "arm_control=0x200\nkernel_old=1" | sudo tee mnt/config.txt
	sudo umount mnt

kernel.img:out.elf
	aarch64-linux-gnu-objcopy -O binary out.elf kernel.img

out.elf:vectors.o memmap hdmi.o font.o
	${LINKER} ${LFLAGS} vectors.o hdmi.o font.o -T memmap -o out.elf

vectors.o:vectors.s header.s
hdmi.o:hdmi.s header.s
font.o:font.s raw.bin

clean:
	rm -rf vectors.o
	rm -rf kernel.img
	rm -rf out.elf
	rm -rf hdmi.o
	rm -rf font.o
	rm -rf mnt
	rm -rf sd.img

test: kernel.img
	qemu-system-aarch64 -machine raspi3b -kernel kernel.img
gdb: kernel.img
	qemu-system-aarch64 -machine raspi3b -kernel kernel.img -s -S

