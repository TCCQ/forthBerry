.include "header.s"
	//this file should include stuff for getting video out of hdmi
	//most of it will live in data 2 subsection, or the text 2 section or the bss section
	//mostly made from
	//https://github.com/isometimes/rpi4-osdev/tree/master/part5-framebuffer

	.text 2
	//so these are literal values for various mailbox stuff. they should all (hopefully) be 4 byte values
	
	
	//macros for readable names for address constants,
	//all should expand to GAS literal pool values and should automatically reuse values
				// {{{
.balign 32
PERIPH_BASE:
	.word 0x3F000000
VIDEOCORE_MBOX:
	.word 0x3F00B880
MBOX_READ:
	.word 0x3F00B880
MBOX_POLL:
	.word 0x3F00B890
MBOX_SENDER:
	.word 0x3F00B894
MBOX_STATUS:
	.word 0x3F00B898
MBOX_CONFIG:
	.word 0x3F00B89C
MBOX_WRITE:
	.word 0x3F00B8A0

				// }}}
	
	//these are masks for the status hardware reg
				// {{{

MBOX_RESPONSE:
	.word 0x80000000
MBOX_FULL:
	.word 0x80000000
MBOX_EMPTY:
	.word 0x40000000

				// }}}
	
	//these are things we can request through the video core mailbox
				// {{{

MBOX_TAG_SETPOWER:
	.word 0x28001
MBOX_TAG_SETCLKRATE:
	.word 0x38002
MBOX_TAG_SETPHYWH:
	.word 0x48003
MBOX_TAG_SETVIRTWH:
	.word 0x48004
MBOX_TAG_SETVIRTOFF:
	.word 0x48009
MBOX_TAG_SETDEPTH:
	.word 0x48005
MBOX_TAG_SETPXLORDR:
	.word 0x48006
MBOX_TAG_GETFB:
	.word 0x40001
MBOX_TAG_GETPITCH:
	.word 0x40008
	.set MBOX_TAG_LAST, 0

				// }}}

	//kinds of a calls we can do
				// {{{

	.set MBOX_CH_POWER, 0
	.set MBOX_CH_FB, 1
	.set MBOX_CH_VUART, 2
	.set MBOX_CH_VCHIQ, 3
	.set MBOX_CH_LEDS, 4
	.set MBOX_CH_BTNS, 5
	.set MBOX_CH_TOUCH, 6
	.set MBOX_CH_COUNT, 7
	.set MBOX_CH_PROP, 8

	.set MBOX_REQUEST, 0 //this is also here
				// }}}

	//mailbox stuff
	// {{{

	//reserve some space
	.bss
	.balign 16 //allows passing only 28 upper bits of addr
mailbox:
	.skip 144 //36 x 4 byte words


	
	.text 2
	
	//expects the channel number in x20, 0-15
	//returns 0 or nonzero in x21 for success or failure response from vidcore
request_and_wait:
	mov x7,#0xF0F0
	//get the absolute value of mailbox into x17
	adrp x17, :pg_hi21:mailbox
	add x17, x17, #:lo12:mailbox
	//got mailbox addr, want low 4 bits to be channel

	//unclear whether this clobbers top word
	and w17, w17, #0xFFFFFFF0
	and w20, w20, #0x0000000F
	orr w17,w17,w20
	//mailbox addr + channel is now in x17

	adrp x16, :pg_hi21:MBOX_FULL
	ldr w16, [x16, #:lo12:MBOX_FULL]
	adrp x18, :pg_hi21:MBOX_STATUS
	ldr w18, [x18,#:lo12:MBOX_STATUS] //should clear top word
	//contains vidcore register for status
wait:
	mov x7,#0xFF00
	ldr w19, [x18]
	and w19, w19, w16
	cbnz w19, wait //not ready yet, still full

	//out of the loop
	adrp x18, :pg_hi21:MBOX_WRITE
	ldr w18, [x18, #:lo12:MBOX_WRITE]
	//write register
	str w17, [x18] //tell it where our mailbox is

	adrp x16, :pg_hi21:MBOX_EMPTY
	ldr w16, [x16,#:lo12:MBOX_EMPTY] //empty
	adrp x18, :pg_hi21:MBOX_STATUS
	ldr w18, [x18, #:lo12:MBOX_STATUS] //status

response_wait:
	mov x7, 0xEE00
	ldr w19, [x18]
	and w19, w19, w16 //is empty?
	cbnz w19, response_wait //still empty

	//reuse x19 to avoid clobbering x16
	adrp x19, :pg_hi21:MBOX_READ
	ldr w19, [x19,#:lo12:MBOX_READ] //read
	
	//is the respose for us?
	ldr w19, [x19]
	sub x19, x19, x17 //was this our request
	cbnz x19, response_wait //didn't match

	//did match, is this a positive response?
	adrp x17, :pg_hi21:mailbox
	add x17, x17, #:lo12:mailbox
	//check mailbox's second word
	add x17, x17, #4
	ldr w18, [x17]
	eor x21, x21, x21 //clear double word
	mov w16, MBOX_RESPONSE
	sub w21, w18, w16 //success? (bottom word), zero if success
	ret


	//make readable. stores a LITERAL and increments within the mailbox
	.macro SET_MBOX_LIT val
	mov w18, \val
	str w18, [x17, x16]
	add x16, x16, #4
	.endm
	//same thing but pulls 4 bytes from addr to do it
	.macro SET_MBOX_ADDR addr
	adrp x18, \addr //get top 52 bits of addr (page)
	ldr w18, [x18, #:lo12:\addr]
	str w18, [x17, x16]
	add x16, x16, #4
	.endm

	// }}}

	
	//request a framebuffer
	//see https://github.com/isometimes/rpi4-osdev/blob/master/part5-framebuffer/fb.c
	//see https://github.com/raspberrypi/firmware/wiki/Mailbox-property-interface
	.globl fb_init
fb_init:
	mov x7, #0x0F0F
	//get the addr of the mailbox in x17
	adrp x17, :pg_hi21:mailbox
	add x17, x17, #:lo12:mailbox
	//use x16 to increment x17
	eor x16, x16, x16
	
	//length of our message
	SET_MBOX_LIT #140 //35*4
	
	//what kind of message
	SET_MBOX_LIT MBOX_REQUEST
	
	//set the width and height
	SET_MBOX_ADDR MBOX_TAG_SETPHYWH
	SET_MBOX_LIT #8
	SET_MBOX_LIT #8
	SET_MBOX_LIT #1920
	SET_MBOX_LIT #1080
	
	//do the same for the virtual height
	SET_MBOX_ADDR MBOX_TAG_SETVIRTWH
	SET_MBOX_LIT #8
	SET_MBOX_LIT #8
	SET_MBOX_LIT #1920
	SET_MBOX_LIT #1080

	//virtual offset
	SET_MBOX_ADDR MBOX_TAG_SETVIRTOFF
	SET_MBOX_LIT #8
	SET_MBOX_LIT #8
	SET_MBOX_LIT #0
	SET_MBOX_LIT #0

	//depth
	SET_MBOX_ADDR MBOX_TAG_SETDEPTH
	SET_MBOX_LIT #4
	SET_MBOX_LIT #4
	SET_MBOX_LIT #32 //bits per pixel

	//pixel order
	SET_MBOX_ADDR MBOX_TAG_SETPXLORDR
	SET_MBOX_LIT #4
	SET_MBOX_LIT #4
	SET_MBOX_LIT #1 //(A)RGB

	//get a framebuffer
	SET_MBOX_ADDR MBOX_TAG_GETFB
	SET_MBOX_LIT #8
	SET_MBOX_LIT #8
	SET_MBOX_LIT #4096 //TODO ptr? not sure I get this
	SET_MBOX_LIT #0 //TODO size?

	//get pitch
	SET_MBOX_ADDR MBOX_TAG_GETPITCH
	SET_MBOX_LIT #4
	SET_MBOX_LIT #4
	SET_MBOX_LIT #0 //TODO bytes per line ?

	SET_MBOX_LIT MBOX_TAG_LAST

	//did it work?
	push x17 //save our address register
	push x30 //we want to go one deeper
	mov x20, MBOX_CH_PROP
	bl request_and_wait
	mov x7, #0x00FF
	pop x30
	pop x17 //restore
	
	ldr w18, [x17, #80]
	ldr w19, [x17, #112]
	
	sub w18, w18, #32
	cbnz w18, failure //depth is not 32 bbp
	cbz w19, failure //addr is zero

	//we are all good
	//get real address
	eor x20, x20, x20 //zeroed
	ldr x18, #=0x3FFFFFFF
	and w20, w19, w18
	eor x21, x21, x21
	ldr w21, [x17, #20] //width
	eor x22, x22, x22
	ldr w22, [x17, #24] //height
	eor x23, x23, x23
	ldr w23, [x17, #132] //bytes per line
	eor x24, x24, x24
	ldr w24, [x17, #96] //pixel order

	//now put it all in the reserved spots for them in bss
	adrp x19, :pg_hi21:fb_width
	add x19, x19,#:lo12:fb_width 
	str x21, [x19] //width
	str x22, [x19, #8] //height
	str x20, [x19, #16] //addr
	str x23, [x19, #24] //pitch
	ret
failure:
	//return all zeros if something went wrong, addr should never be zero
	eor x20, x20, x20 //zeroed
	eor x21, x21, x21
	eor x22, x22, x22
	eor x23, x23, x23
	eor x24, x24, x24
	ret


	.bss
	.balign 8
fb_width:
	.skip 8
fb_height:
	.skip 8
fb_addr:
	.skip 8
fb_pitch:
	.skip 8
	//I guess I could put pixel order here too but idk if we need it atm
	
	.text 2
	//takes x pos in x20
	//y in x21
	//color as ARGB in w22
	//probably better to not use builtin stuff for speed but whatever
	.globl set_pixel
set_pixel:
	adrp x19, :pg_hi21:fb_width
	add x19, x19,#:lo12:fb_width 
	ldr x18, [x19] //width
	ldr x17, [x19, #8] //height
	ldr x16, [x19, #16] //addr
	ldr x19, [x19, #24] //pitch
	cmp x20, x18 //sets flags
	b.ge out_of_bounds
	cmp x20, #0
	b.lt out_of_bounds
	cmp x21, x17 //sets flags
	b.ge out_of_bounds
	cmp x21, #0
	b.lt out_of_bounds

	lsl x18, x20, #2 //x*4
	madd x18, x19, x21, x18 // y*pitch + x
	str w22, [x16, x18]
out_of_bounds:
	ret
	

	//takes ascii code in x20, x in x21, y in x22 and puts that char at that pixel in 8x16 font
	//clobbers 
	//puts that character in 8x16 font at that pixel
	.globl set_char
set_char:
	lsl x15, x21, #2 //x * 4 for word addressing
	mov x16, #0
	movk x16, #0xFFFF
	movk x16, #0xFFFF, lsl 16 //w16 all 1s
	
	.global font_get_character
	bl font_get_character //puts top half in x21, bottom half in x22

	adrp x17, :pg_hi21:fb_addr
	add x17, x17,#:lo12:fb_addr
	ldr x18, [x17] //addr
	ldr x17, [x17, #8] //pitch
	madd x19, x22, x17, x15 //y * pitch + x
	add x19, x19, x18 //char origin addr

	mov x12, #0 //top / bottom half selector
	mov x15, #0 //pixel x offset within char
	mov x14, #0 //pixel y offset within char
half:
	lsl x13, x14, #3 //y*8
	lsr x13, x21, x13 //shift for y
	lsr x13, x13, x15 //shift for x
	and x13, x13, #0x01 //bottom bit (sets zero flag)
	csel w13, wzr, w16, eq //fill 1s if x13 & 1, else fill zeros
	//w13 is now color we want

	add x11, x12, x14 //half selector + y
	madd x18, x11, x17, x15 //linear pixel offset from origin
	str w13, [x19, x18] //color @ origin + offset

	add x15, x15, #1 //increment x
	lsr x13, x15, #3 
	and x13, x13, #1 //do we need a pixel carrage return?
	add x14, x14, x13 //do said increment ^ 
	and x15, x15, #0x07 //keep x values in [0,7]
	cmp x14, #8
	b.lt half

	cmp x12, #8
	beq set_char_out //we are done
	mov x12, #8 //do bottom half now
	mov x21, x22 //use other half of char
	mov x15, #0
	mov x14, #0
	b half
set_char_out:
	ret
	
