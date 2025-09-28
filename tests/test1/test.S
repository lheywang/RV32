	.text
	.globl 	_start

_start:
	li 		x1,		5				// R1 	<- 	5
	li	 	x2, 	7				// R2 	<- 	7

	// Basics maths
	add 	x3, 	x1, 	x2		// R3 	<- 	R1 + R2 	(12)
	sub 	x4,		x2,		x1		// R4 	<- 	R2 - R2 	(2)

	// Immediates maths
	addi 	x5,		x1,		10		// R5 	<-	R1 + 10 	(15)

	// Basics logics
	and 	x10,	x1,		x2 		// R10 	<-	R1 & R2 	(5)
	not 	x11, 	x1				// R11 	<-	~R2			(111...010)
	xor 	x12,	x1,		x2		// R12 	<-	R1 ^ R2 	(2)
	or 		x13,	x1,		x2		// R13 	<-	R1 | R2		(7)
	andi	x14,	x2,		3		// R14 	<-	R1 & 0x3	(3)	
	xori 	x15,	x1,		10		// R15 	<- 	R1 ^ 0xA	(F)
	ori		x16,	x1,		1		// R16 	<-	R1 | 0x1	(5)

	// Shifts
	slli 	x20,	x1,		1		// R20 	<-	R1 << 1		(10)
	srli	x21,	x1,		1		// R21 	<-	R1 >> 1		(2)