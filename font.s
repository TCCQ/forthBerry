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
	//clobbers x15-x19
	.globl font_get_character
font_get_character:
	//reminder the calc is
	//[base + (code & 0x0F) + (pitch * ((code & 0xF0) + line) )]

	and x20, x20, #0xFF //clean data
	mov x15, #16 //pitch, needs a register for multiply 
	
	adrp x16, :pg_hi21:font
	add x16, x16, #:lo12:font
	//x16 is now base address of font
	
	mov x21, #0 //clear destination
	mov x17, #0 //this will be the line counter
top_half:
	and x18, x20, #0xF0 //character orgin y
	add x18, x18, x17 //line number, x18 is now final y
	and x19, x20, #0x0F //character origin x
	madd x19, x15, x18, x19 //offset = (pitch * y) + x
	ldrb w18, [x16, x19] //base + offset
	lsl x19, x16, #3 //multiply line by 8 for bit shift
	lsl x18, x18, x19 //shift byte up by lineNum * 8
	orr x21, x21, x18 //include in accumulating top half
	add x17, x17, #1 //inc line
	cmp x17, #8
	b.lt top_half

	mov x22, #0 //clear destination
	mov x17, #0 //this will be the line counter
bottom_half:
	and x18, x20, #0xF0 //character orgin y
	add x18, x18, x17 //line number, x18 is now final y
	and x19, x20, #0x0F //character origin x
	madd x19, x15, x18, x19 //offset = (pitch * y) + x
	ldrb w18, [x16, x19] //base + offset
	lsl x19, x16, #3 //multiply line by 8 for bit shift
	lsl x18, x18, x19 //shift byte up by lineNum * 8
	orr x22, x22, x18 //include in accumulating top half
	add x17, x17, #1 //inc line
	cmp x17, #8
	b.lt bottom_half 
	ret 
	
