	.include "header.s"
	//execution starts here
	//first thing to do is isolate master core
	.text 0
	.globl _start	
_start:
	mov x7,#0xFFFF
	mrs x0,mpidr_el1
	mov x1,#0xC1000000
	bic x0,x0,x1
	cbz x0,master
	b hang
master:
	//only the master core sees this
	//set up our three main stacks
	//the register is addr to first empty thing on top of the stack

	//effective program stack (RSTACK), grows down
	mov RSTACK, #0x010000
	//alloc stack, grows up
	ldr ASTACK, #=0x010008
	//forth main stack (arg stack), grows down
	ldr STACK, #=0x100000

	//testing
	.globl fb_init
	bl fb_init //get us a framebuffer
	cbz x20, hang //something went wrong
	//otherwise


	b hw
	
	//full ascii test
	mov x20, #0
a_test:
	ubfx x21, x20, #0, #4
	ubfx x22, x20, #4, #4
	lsl x21, x21, #4
	lsl x22, x22, #5
	.global set_char
	bl set_char
	add x20, x20, #1
	cmp x20, #0xFF
	b.le a_test
	b hang


hw:	
	mov x21, #0 //x pixel offset
	mov x22, #0 //y
	adrp x0, :pg_hi21:text_hold
	add x0, x0, #:lo12:text_hold //text addr
	mov x1, #0 //x
t_loop:
	ldrb w20, [x0, x1]
	cbz w20, hang
	//x21 and x22 are alredy set
	.global set_char
	bl set_char
	add x1, x1, #1
	add x21, x21, #8
	b t_loop
text_hold:
	.asciz "Hello World!"
	.balign 16
hang:
	//just wait forever
	b hang


