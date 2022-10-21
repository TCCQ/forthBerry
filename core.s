	//this file should have the asembly for some of the basic words that forth needs
	//this it will use the same naming scheme as forth-standard.org

	//it assumes:
	//rstack is in RSTACK, and grows down
	//alloc stack is in ASTACK, grows up
	//main stack (arg stack) is in STACK, grows down
	//each reg is the address of the next empty value
	//they are 8byte aligned, generally
	//---------------------------------------------------------------------------------------------------

	
	//fetch
	//(a-addr -- x)
	//x is value stored at a-addr (1 cell?)
fetch:
	//I am not going to touch the stack ptr here
	//because we push and pop one each, so we can do it with offsets
	ldr x15, [STACK, #8] //pop the addr off the stack
	ldr x16, [x15] //load value at given address
	str x16, [STACK, #8] //push back to stack
	ret

	//store
	//(x a-addr -- )
	//store x at a-addr
store:
	sub STACK, STACK, #16
	ldr x15, [STACK, #8] //get address
	ldr x16, [STACK] //get value
	str x16, x15 //do the store
	ret

	//equals
	//(x x -- flag)
	//true if they are bit for bit equal
equals:
	add STACK, STACK, #8 //pop
	ldr x15, [STACK] //arg 1 (above stack)
	ldr x16, [STACK, #8] //arg 2 (top of stack)
	//got operands
	cmeq x19, x15, x16 //check for equality
	str x19, [STACK, #8] //(top of stack)
	ret

	//zero-equals
	//(x -- flag)
	//true if zero
zero-equals:
	ldr x15, [STACK, #8] //get address
	cmeq x19, x15, #0
	//compare against zero
	str x19, [STACK, #8]
	ret

	//plus
	//(n/u n/u -- n/u)
	//return the sum.
	//I am totally ignoring unsigned numbers currently
plus:
	add STACK, STACK, #8 //pop
	ldr x15, [STACK] //above stack
	ldr x16, [STACK, #8] //top of stack
	//got operands
	add x19, x15, x16
	str x19, [STACK, #8] //write back (top of stack)
	ret

	//minus
	//(n/u n/u -- n/u)
	//return the difference.
	//I am totally ignoring unsigned numbers currently
minus:
	add STACK, STACK, #8
	ldr x15, [STACK] //above stack
	ldr x16, [STACK, #8] //top of stack
	//got operands
	sub x19, x15, x16
	str x19, [STACK, #8] //write back (top of stack)
	ret

	//star
	//(n/u n/u -- n/u)
	//return the product
	//I am ignoring unsiged numbers currently
star:
	add STACK, STACK, #8
	ldr x15, [STACK] //above stack
	ldr x16, [STACK, #8] //top of stack
	//got operands
	mul x19, x15, x16
	str x19, [STACK, #8] //write back (top of stack)
	ret

	//drop
	//(x -- )
	//pop the top cell of the stack
drop:
	add STACK, STACK, #8 //pop
	ret

	//dupe
	//(x -- x x)
	//duplicate x
dupe:
	ldr x15, [STACK, #8] //top of stack
	str x15, [STACK] //above stack
	sub STACK, STACK, #8 //push up
	ret
	
	//allot
	//(n -- )
	//adds or removes from the ASTACK 
allot:
	add STACK, STACK, #8 //pop main stack	
	ldr x15, [STACK]
	add ASTACK, ASTACK, x15 //inc/dec allot stack as directed, (+ is alloc, - is free)
	ret //uses x30 to return, this is a leaf procedure

	//comma
	//(x --)
	//reserve a cell and store x in it
comma:
	add STACK, STACK, #8 //pop main stack	
	ldr x15, [STACK] //get value
	str x15, [ASTACK] //store in open cell
	add ASTACK, ASTACK, #8 //inc alloc stack
	ret 

	
