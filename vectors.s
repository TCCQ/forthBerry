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

	mov x21, #0 //x pixel offset
	mov x22, #0 //y
	adrp x23, :pg_hi21:text_hold
	add x23, x23, #:lo12:text_hold //text addr
	mov x24, #0 //x
t_loop:
	ldrb w25, [x23, x24]
	cbz w25, hang
	mov w20, w25 //ascii
	//x21 and x22 are alredy set
	.global set_char
	bl set_char
	add x24, x24, #1
	add x21, x21, #8
	b t_loop
text_hold:
	.asciz "Hello World!"
	.balign 16
hang:
	//just wait forever
	b hang


