	//This is a macro header for all asembly files

	//main argument stack (grows down)
	STACK .req x27

	//return stack (grows down)
	//also refered to as 'sp' sometimes
	RSTACK .req sp

	//alloc stack (grows up)
	ASTACK .req x28

	//macro to push a register
	.macro push reg
	str \reg, [RSTACK]
	sub RSTACK, RSTACK, #8
	.endm

	//macro to pop reg
	.macro pop reg
	add RSTACK, RSTACK, #8
	ldr \reg, [RSTACK]
	.endm
