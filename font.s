	.include "header.s"
	//this file is the bitmap font I will be using and related data
	//it is in 1bpp with each character as 8x16 pixels
	//its bizcat, found online
	//the characters are arranged in rows of 16, of which there are 16 rows
	//it covers ascii
	//so given an ascii code, get the character index (just high and low 4bits)
	//then the origin of the character is baseAddress + x + (pitch * (y * 16))
	//with pitch as 16, the total number of bytes per line
	//then from the origin, to get pixel (px,py), do
	// (byte) (origin + (pitch * py)) bit number px
	.data
font:	
	.incbin "raw.bin"

	.text
	//helper function for sampling a single character given the ascii code
	//take ascii code in x20 lowest byte, returns top half in x21, and bottom half in x22 in row major order
	//clobbers x13-x19, writes to x21, x22, preserves x20
	.globl font_get_character
font_get_character:
	//reminder the calc is
	//[base + (code & 0x0F) + (pitch * ((code & 0xF0) + line) )]

	//uxtb w20, w20 //clean data to byte
	//pitch is #16
	
	adrp x16, :pg_hi21:font
	add x16, x16, #:lo12:font
	//x16 is now base address of font

	//because my font was in a bmp, y = 0 is the bottom
	//this is dumb and bad, so I am going to fix this here
	//all code above this should treat y=0 as the top

	ubfx x18, x20, #0, #4 //bottom 4 bits as char origin x
	add x16, x16, x18 //offset for x
	ubfx x18, x20, #4, #4 //top 4 is char origin y, but needs to be scaled
	lsl x18, x18, #4 //scale y, char is 16 rows tall
	mov x19, #0xEF
	sub x18, x19, x18 //count from the bottom
	lsl x18, x18, #4 //scale again, because each row is 16 bytes
	add x16, x16, x18 //offset for y

	//now offsets by pitch from x16 are rows
	//and adding pitch takes you UP one row in the char

	mov x13, #0 //marker, should be able to fold into another reg somewhere
	mov x21, #0 //clear destination (copies on half change)
	mov x17, #0 //row counter
half:
	ldrb w14, [x16] //get row
 	rbit w14, w14
	lsr w14, w14, #24 //reverse bit order, so low bit is leftmost and highest is rightmost
	mov x15, #7
	sub x15, x15, x17 //get row idx from top
	lsl x15, x15, #3 //scale by 8 for bit shift
	lsl x14, x14, x15 //shift data up based on row
	orr x21, x21, x14 //accumulate data 

	add x16, x16, #16 //add pitch 
	add x17, x17, #1
	cmp x17, #8
	b.lt half
	
	//we finished a half
 	cbnz x13, get_char_out

	mov x13, #1
	mov x22, x21 //save first half
	mov x21, #0
//	lsl x17, x17, #4 //scale by pitch
//	add x16, x16, x17 //offset to point to bottom half
	mov x17, #0
	b half
	
get_char_out:
	ret
