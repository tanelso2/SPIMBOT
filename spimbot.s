.data
three:	.float	3.0
five:	.float	5.0
PI:	.float	3.141592
F180:	.float  180.0
	
.align 2
flags: .space 320 #reserves a block that can hold 80 ints (40 x,y coord pairs)
sudoku_board: .space 512
symbollist: .ascii  "0123456789ABCDEFG"
target_x: 	.word 0
target_y: 	.word 0
invis_state: .word 0

# spimbot constants
NUM_FLAGS = 40	# maximum flags you can ever have on the board
BASE_RADIUS = 24
MAX_FLAGS = 5	# maximum flags you can have in hand (might not be optimal though)
FLAG_COST = 7
INVIS_COST = 25
BASE_X = 15
BASE_Y = 150

# memory-mapped I/O
VELOCITY = 0xffff0010
ANGLE = 0xffff0014
ANGLE_CONTROL = 0xffff0018
BOT_X = 0xffff0020
BOT_Y = 0xffff0024
FLAG_REQUEST = 0xffff0050
PICK_FLAG = 0xffff0054
FLAGS_IN_HAND = 0xffff0058
GENERATE_FLAG = 0xffff005c
ENERGY = 0xffff0074
ACTIVATE_INVIS = 0xffff0078
PRINT_INT = 0xffff0080
PRINT_FLOAT = 0xffff0084
PRINT_HEX = 0xffff0088
SUDOKU_REQUEST = 0xffff0090
SUDOKU_SOLVED = 0xffff0094
OTHER_BOT_X = 0xffff00a0
OTHER_BOT_Y = 0xffff00a4
COORDS_REQUEST = 0xffff00a8
SCORE = 0xffff00b0
ENEMY_SCORE = 0xffff00b4

# interrupt memory-mapped I/O
TIMER = 0xffff001c
BONK_ACKNOWLEDGE = 0xffff0060
COORDS_ACKNOWLEDGE = 0xffff0064
TIMER_ACKNOWLEDGE = 0xffff006c
TAG_ACKNOWLEDGE = 0xffff0070
INVIS_ACKNOWLEDGE = 0xffff007c

# interrupt masks
TAG_MASK = 0x400
INVIS_MASK = 0x800
BONK_MASK = 0x1000
COORDS_MASK = 0x2000
TIMER_MASK = 0x8000

# syscall constants
PRINT_STRING = 4
PRINT_CHAR = 11

.text
main:
	li	$t4, TIMER_MASK	# timer interrupt enable bit
	or	$t4, $t4, COORDS_MASK # coords interrupt bit
	or	$t4, $t4, BONK_MASK # bonk interrupt bit
	or	$t4, $t4, INVIS_MASK	#invis interrupt bit
	or	$t4, $t4, TAG_MASK #tag interrupt bit
	or	$t4, $t4, 1	# global interrupt enable
	mtc0	$t4, $12	# set interrupt mask (Status register)

	li $s0, 10
	sw $s0, VELOCITY($zero) #vroom vroom let's get going
	lw $t0, TIMER($zero)
	add $t0, $t0, 10
	sw $t0, TIMER($zero) #requesting an interrupt because I put most of the logic in the interrupt handler

	# start monitoring other bot's location
	sw $t0, COORDS_REQUEST($zero)
	lw  $a0, OTHER_BOT_X($zero)         # get other bot's x loc
    la  $t0, target_x
    sw  $a0, 0($t0)             # store new target_x

    lw  $a0, OTHER_BOT_Y($zero)         # get other bot's y loc
    la  $t0, target_y
    sw  $a0, 0($t0)             # store new target_y

	# start going invisible
#	sw $t0, ACTIVATE_INVIS($zero)

pickup_loop:
	sw $t4, PICK_FLAG($zero)		#so instead of this loop, another thing
#	lw  $t0, FLAGS_IN_HAND($zero)
#
#    li  $t1, 3
#    ble $t0, $t1, ok1
#
#    sw  $zero, ACTIVATE_INVIS($zero)
#

ok1:


	la $a0, sudoku_board
	sw $a0, SUDOKU_REQUEST($zero) 	# make sudoku request to fill sudoku board, $a0 is also set up to be passed into rule1
	
	sub 	$sp, $sp, 4
	
solve: 	
	la  $a0, sudoku_board					# solve (right now only implemented with rule1, so it's slower than it needs to be)
	jal rule1
	sw	$v0, 0($sp)			# store result to memory so it can't be corrupted
	la	$a0, sudoku_board
	jal rule2
	lw 	$t0, 0($sp)
	or 	$t0, $v0, $t0
	bne $t0, $zero, solve
	
	add 	$sp, $sp, 4
#
#	lw  $t0, FLAGS_IN_HAND($zero)
#	
#	li 	$t1, 3
#	ble $t0, $t1, ok
#	
#	sw 	$zero, ACTIVATE_INVIS($zero)
#
#
ok:
	la 	$a0, sudoku_board
	jal print_board			# for debugging
	la $a0, sudoku_board
	sw 	$a0, SUDOKU_SOLVED($zero) 	# get 25 energy points (if the solver works)
#	mfc0 $t0, $13
#	and $t0, $t0, INVIS_MASK
#	beq $t0, $zero, after
#	sw 	$zero, ACTIVATE_INVIS($zero)
after:
	j pickup_loop	
				


## bool
## rule1(unsigned short board[GRID_SQUARED][GRID_SQUARED]) {
##   bool changed = false;
##   for (int i = 0 ; i < GRID_SQUARED ; ++ i) {
##     for (int j = 0 ; j < GRID_SQUARED ; ++ j) {
##       unsigned value = board[i][j];
##       if (has_single_bit_set(value)) {
##         for (int k = 0 ; k < GRID_SQUARED ; ++ k) {
##           // eliminate from row
##           if (k != j) {
##             if (board[i][k] & value) {
##               board[i][k] &= ~value;
##               changed = true;
##             }
##           }
##           // eliminate from column
##           if (k != i) {
##             if (board[k][j] & value) {
##               board[k][j] &= ~value;
##               changed = true;
##             }
##           }
##         }
## 
##         // elimnate from square
##         int ii = get_square_begin(i);
##         int jj = get_square_begin(j);
##         for (int k = ii ; k < ii + GRIDSIZE ; ++ k) {
##           for (int l = jj ; l < jj + GRIDSIZE ; ++ l) {
##             if ((k == i) && (l == j)) {
##               continue;
##             }
##             if (board[k][l] & value) {
##               board[k][l] &= ~value;
##               changed = true;
##             }
##           }
##         }
##       }
##     }
##   }
##   return changed;
## }

rule1:
	sub	$sp, $sp, 32
	sw 	$ra, 0($sp)
	sw	$s0, 4($sp)
	sw	$s1, 8($sp)	
	sw 	$s2, 12($sp)
	sw 	$s3, 16($sp)
	sw 	$s4, 20($sp)		# holds array start ptr
	sw 	$s5, 24($sp)   		# holds value
	sw 	$s6, 28($sp)		# k	

	move 	$s4, $a0		# grab onto array ptr

	li 	$s0, 16 		# GRID_SQUARED = constant 16
	li 	$s1, 0 			# changed = false
	li 	$s2, -1			
r1loop1:
	add 	$s2, $s2, 1		# i = 0, increments i
	bge 	$s2, $s0, ret_changed
	li 	$s3, -1			
r1loop2:
	add 	$s3, $s3, 1		# j = 0, increments j
	bge 	$s3, $s0, r1loop1
	mul 	$t0, $s2, 16		# i*16
	add 	$t0, $t0, $s3		# i*16 + j
	sll 	$t0, $t0, 1		# mult by 2 (dealing with halfs)
	add 	$t0, $s4, $t0		# add indexing to ptr
	lhu 	$s5, 0($t0)		# value = board[i][j]
	move 	$a0, $s5
	jal 	has_single_bit_set 	# $v0 = yes or no
	beq	$v0, $zero, r1loop2
	li	$s6, -1	
r1loop3:
	add 	$s6, $s6, 1		# k = 0, increments k
	bge	$s6, $s0, elim_square
	beq 	$s6, $s3, elim_column	# k != j
	mul	$t0, $s2, 16		# i*16
	add 	$t0, $t0, $s6		# i*16 + k
	sll 	$t0, $t0, 1		# << 1
	add 	$t0, $t0, $s4		# address of board[i][k]	
	lhu	$t1, 0($t0)		# board[i][k]
	and 	$t2, $t1, $s5		# board[i][k] & value
	beq 	$t2, $zero, elim_column
	not 	$t2, $s5
	and 	$t1, $t2, $t1 		# board[i][k] & ~value
	sh	$t1, 0($t0)		# board[i][k] &= ~value
	li	$s1, 1			# changed = true
elim_column:
	beq 	$s6, $s2, r1loop3	
	mul	$t0, $s6, 16		# k*16
	add 	$t0, $t0, $s3		# k*16 + j
	sll 	$t0, $t0, 1		# << 1
	add 	$t0, $s4, $t0		# address of board[k][j]
	lhu 	$t1, 0($t0)		# board[k][j]
	and	$t2, $t1, $s5		# board[k][j] & value
	beq 	$t2, $zero, r1loop3	
	not 	$t2, $s5		# ~value
	and 	$t1, $t1, $t2		# board[k][j] & ~value
	sh 	$t1, 0($t0)		# board[k][j] &= ~value
	li 	$s1, 1			# changed = true
	j 	r1loop3

elim_square:	
	move 	$a0, $s2
	jal 	get_square_begin
	move 	$s6, $v0		# $s6 = ii = k
	move 	$a0, $s3
	jal 	get_square_begin 	# jj = $v0
	add	$t0, $s6, 4		# $t0 = ii + GRIDSIZE
	add 	$t1, $v0, 4		# $t1 = jj + GRIDSIZE

	sub 	$s6, $s6, 1 	
r1loop4:
	add 	$s6, $s6, 1		# increments k
	bge	$s6, $t0, r1loop2	# k < ii + GRIDSIZE
	move 	$t2, $v0 		# l = jj
	sub 	$t2, $t2, 1
r1loop5:
	add 	$t2, $t2, 1		# increment l
	bge 	$t2, $t1, r1loop4
	xor 	$t3, $s6, $s2
	xor 	$t4, $t2, $s3		
	or 	$t4, $t4, $t3		
	beq	$t4, $zero, r1loop5	# if k==i and l==j continue
	mul	$t5, $s6, 16 		# k*16
	add 	$t5, $t5, $t2		# k*16 + l
	sll 	$t5, $t5, 1		# << 1
	add 	$t5, $s4, $t5 		# holds address of board[k][l]
	lhu 	$t6, 0($t5)		# board[k][l]
	and 	$t7, $t6, $s5		# board[k][l] & value
	beq 	$t7, $zero, r1loop5	
	not 	$t7, $s5 		# ~value
	and 	$t6, $t6, $t7		# board[k][l] & ~value
	sh 	$t6, 0($t5)		# board[k][l] &= ~value
	li 	$s1, 1			# changed = true
	j 	r1loop5

ret_changed:
	move 	$v0, $s1		# changed data moved into return reg
	lw      $ra, 0($sp)
    lw      $s0, 4($sp)
    lw      $s1, 8($sp)
    lw      $s2, 12($sp)
    lw      $s3, 16($sp)
    lw      $s4, 20($sp)          
    lw      $s5, 24($sp)          
    lw      $s6, 28($sp)           

	add 	$sp, $sp, 32

	jr	$ra

has_single_bit_set:
	bne 	$a0, $zero, other_if	# test if value equals zero
	move 	$v0, $zero				# if so, return 0 (data flow)
	jr 		$ra						# return to calling function (control flow)
other_if:	
	add 	$t0, $a0, -1 			# $t0 = value - 1
	and 	$t0, $a0, $t0			# $t0 = value & (value - 1)
	beq 	$t0, $zero, return_1	# test if value & (value - 1) is 1
	move 	$v0, $zero				# return 0 (data flow)
	jr 		$ra						# return to calling function (control flow)
return_1: 
	li 		$v0, 1					# return 1
	jr		$ra						# return to caller


get_lowest_set_bit:
	li 		$t0, 0					# $t0 = 0 ($t0 is i)
	li 		$t1, 16					# $t1 = 16 ($t1 is 16)
loop:	
	bge 	$t0, $t1, return_0		# test if i < 16
	li 		$t3, 1					# $t3 = 1
	sll 	$t2, $t3, $t0			# $t2 = 1 << i
	and 	$t4, $a0, $t2			# $t4 = value & (1 << i)
	beq 	$t4, $zero, incr_1 		# test if $t4 is 1
	move 	$v0, $t0				# return i
	jr 		$ra
incr_1: 
	add 	$t0, $t0, 1				# increment i
	j 		loop					# jump back to test the condition in the foor loop

return_0:
	move 	$v0, $zero				# return 0
	jr 		$ra

get_square_begin:
	# round down to the nearest multiple of 4
	and	$v0, $a0, 0xfffffffc
	jr	$ra

rule2:
	sub		$sp, $sp, 36		
	sw		$ra, 0($sp)
	sw		$s0, 4($sp)
	sw		$s1, 8($sp)
	sw		$s2, 12($sp)
	sw		$s3, 16($sp)
	sw		$s4, 20($sp)
	sw		$s5, 24($sp)
	sw		$s6, 28($sp)
	sw		$s7, 32($sp)

	move 	$s0, $a0			#&board[0][0]

	li		$s1, 0				#changed = false
	li		$s2, -1				#i=-1
	li		$s3, 16				#GRID_SQUARED

r2for1:
	add		$s2, $s2, 1			#i++
	bge		$s2, $s3, r2return

	li		$s4, -1				#j=-1
r2for2:
	add		$s4, $s4, 1			#j++
	bge		$s4, $s3, r2endFor2

	mul 	$t0, $s2, 16			# i*16
	add 	$t0, $t0, $s4			# i*16 + j
	sll 	$t0, $t0, 1				# mult by 2 (dealing with halfs)
	add 	$s7, $s0, $t0			# add indexing to ptr
	lhu 	$s5, 0($s7)				# value = board[i][j]
	move 	$a0, $s5
	jal 	has_single_bit_set 		# $v0 = yes or no
	beq		$v0, 1, r2for2		# continue  #####################################

	li		$t0, 0					# jsum = 0
	li		$t1, 0					# isum = 0
	li		$t3, -1					# k=-1

r2kloop:
	add		$t3, $t3, 1				# k++
	bge		$t3, $s3, r2endkloop

	beq		$t3, $s4, r2keqj
	mul		$t4, $s2, 16		# i*16
	add		$t4, $t4, $t3		# i*16+k
	sll		$t4, $t4, 1			# *2
	add		$t4, $t4, $s0
	lhu		$t4, 0($t4) 		# board[i][k]
	or		$t0, $t0, $t4		# jsum |= board[i][k] 
r2keqj:
	beq		$t3, $s2, r2keqi
	# isum |= board[k][j]
	mul		$t4, $t3, 16		# k*16
	add		$t4, $t4, $s4		# k*16+j
	sll		$t4, $t4, 1			# *2
	add		$t4, $t4, $s0	
	lhu		$t4, 0($t4)			# board[k][j]
	or		$t1, $t1, $t4		# isum |= board[k][j]
r2keqi:
	j		r2kloop
r2endkloop:
	
	# ALL_VALUES = (1 << GRID_SQUARED) - 1

	li		$s6, 1
	sll		$s6, $s6, 16
	sub		$s6, $s6, 1			# ALL_VALUES

	beq		$s6,$t0, r2rowDone
	not		$t4, $t0			# ~jsum
	and		$t4, $s6, $t4
	sh		$t4, 0($s7)			# board[i][j] = ALL_VALUES & ~jsum
	li		$s1, 1				# changed = true
	j		r2for2				# continue
r2rowDone:
	beq		$s6, $t1, r2columnDone
	not		$t4, $t1			# ~isum
	and		$t4, $s6, $t4
	sh		$t4, 0($s7)			# board[i][j] = ALL_VALUES & ~isum
	li		$s1, 1				# changed = true
	j		r2for2				# continue
r2columnDone:

	move	$a0, $s2
	jal		get_square_begin
	move	$t0, $v0			# ii
	move	$a0, $s4
	jal		get_square_begin
	move	$t1, $v0			# jj
	li		$t6, 0				# sum = 0

	move	$t2, $t0			# k = ii
	add		$t3, $t2, 4			# ii+GRIDSIZE
r2kloop2:
	bge		$t2, $t3, r2endk2
	
	move	$t4, $t1			# l = jj
	add		$t5, $t4, 4			# jj+GRIDSIZE
r2lloop:
	bge		$t4, $t5, r2endL
		

	bne		$t2, $s2, r2dontContinue
	bne		$t4, $s4, r2dontContinue
	add		$t4, $t4, 1
	j		r2lloop
r2dontContinue:

	# board[k][l]
	mul		$t7, $t2, 16		# k*16
	add		$t7, $t7, $t4		# k*16+l
	sll		$t7, $t7, 1			# *2
	add		$t7, $t7, $s0		# &board[k][l]
	lhu		$t7, 0($t7)			# board[k][l]
	or		$t6, $t6, $t7		# sum |= board[k][l]

	add		$t4, $t4, 1
	j		r2lloop
r2endL:

	add		$t2, $t2, 1
	j		r2kloop2
r2endk2:

	beq		$s6, $t6, r2for2
	not		$t0, $t6			# ~sum
	and		$t0, $s6, $t0		# ALL_VALUES & ~sum
	sh		$t0, 0($s7)
	li		$s1, 1

	j 		r2for2
r2endFor2:
	j		r2for1
r2return:

	move	$v0, $s1			# move changed to return reg
	lw		$ra, 0($sp)
	lw		$s0, 4($sp)
	lw		$s1, 8($sp)
	lw		$s2, 12($sp)
	lw		$s3, 16($sp)
	lw		$s4, 20($sp)
	lw		$s5, 24($sp)
	lw		$s6, 28($sp)
	lw		$s7, 32($sp)
	add		$sp, $sp, 36
	jr		$ra


print_board:
	sub	$sp, $sp, 20
	sw	$ra, 0($sp)		# save $ra and free up 4 $s registers for
	sw	$s0, 4($sp)		# i
	sw	$s1, 8($sp)		# j
	sw	$s2, 12($sp)		# the function argument
	sw	$s3, 16($sp)		# the computed pointer (which is used for 2 calls)
	move	$s2, $a0

	li	$s0, 0			# i
pb_loop1:
	li	$s1, 0			# j
pb_loop2:
	mul	$t0, $s0, 16		# i*16
	add	$t0, $t0, $s1		# (i*16)+j
	sll	$t0, $t0, 1		# ((i*16)+j)*2
	add	$s3, $s2, $t0
	lhu	$a0, 0($s3)
	jal	has_single_bit_set		
	beq	$v0, 0, pb_star		# if it has more than one bit set, jump
	lhu	$a0, 0($s3)
	jal	get_lowest_set_bit	# 
	add	$v0, $v0, 1		# $v0 = num
	la	$t0, symbollist
	add	$a0, $v0, $t0		# &symbollist[num]
	lb	$a0, 0($a0)		#  symbollist[num]
	li	$v0, 11
	syscall
	j	pb_cont

pb_star:		
	li	$v0, 11			# print a "*"
	li	$a0, '*'
	syscall

pb_cont:	
	add	$s1, $s1, 1		# j++
	blt	$s1, 16, pb_loop2

	li	$v0, 11			# at the end of a line, print a newline char.
	li	$a0, '\n'
	syscall	
	
	add	$s0, $s0, 1		# i++
	blt	$s0, 16, pb_loop1

	lw	$ra, 0($sp)		# restore registers and return
	lw	$s0, 4($sp)
	lw	$s1, 8($sp)
	lw	$s2, 12($sp)
	lw	$s3, 16($sp)
	add	$sp, $sp, 20
	jr	$ra





.kdata	# interrupt handler data (separated just for readability)
chunkIH:	.space 166666	
non_intrpt_str:	.asciiz "Non-interrupt exception\n"
unhandled_str:	.asciiz "Unhandled interrupt type\n"


.ktext 0x80000180
interrupt_handler:
.set noat
	move	$k1, $at	# Save $at
.set at
	la	$k0, chunkIH
	sw	$a0, 0($k0)	# Get some free registers
	sw	$a1, 4($k0)	# by storing them to a global variable
	sw $v0, 8($k0)
	sw $t0, 12($k0)
	sw $t1, 16($k0)
	sw $v0, 20($k0)
	sw $s0, 24($k0)
	sw $ra, 28($k0)
	sw $t2, 32($k0)
	sw $t3, 36($k0)


	mfc0	$k0, $13	# Get Cause register
	srl	$a0, $k0, 2
	and	$a0, $a0, 0xf	# ExcCode field
	bne	$a0, 0, non_intrpt

interrupt_dispatch:	# Interrupt:
	mfc0	$k0, $13	# Get Cause register, again
	beq	$k0, 0, done	# handled all outstanding interrupts
	
	and	$a0, $k0, TIMER_MASK	# is there a timer interrupt?
	bne	$a0, 0, timer_interrupt

	and	$a0, $k0, COORDS_MASK
	bne	$a0, 0, coords_interrupt

	and $a0, $k0, BONK_MASK
	bne $a0, 0, bonk_interrupt

	and $a0, $k0, INVIS_MASK
	bne $a0, 0, invis_interrupt

	and $a0, $k0, TAG_MASK
	bne $a0, 0, tag_interrupt

	j	done

# interrupt simply logs the last location of the opponent
coords_interrupt: 
	sw $a1, COORDS_ACKNOWLEDGE($zero)
	sw $a1, COORDS_REQUEST($zero)


    lw  $a0, OTHER_BOT_X($zero)         # get other bot's x loc
    la  $t0, target_x
    sw  $a0, 0($t0)             # store new target_x

    lw  $a0, OTHER_BOT_Y($zero)         # get other bot's y loc
    la  $t0, target_y
    sw  $a0, 0($t0)             # store new target_y


#	lw $t0, BOT_X($zero)
#	lw $t1, BOT_Y($zero)	## get my location

#	sub $a0, $a0, $t0
#	sub $a1, $a1, $t1		# get x and y differences
#
#	jal euclidean_dist		# find euclidean distance away
#	bgt $v0, 200, interrupt_dispatch  # if we're greater then 10 units away, no worries
#
#	# else, check what invis_state we're in ( a. we've never called it before or b. we have and we're at the behest of the invis interrupt), go invisible and continue collecting flags
#	
#	la 	$t0, invis_state
#	lw 	$a0, 0($t0)
#	bne $a0, $zero, invis_state1;
#invis_state0:
#	sw $zero, ACTIVATE_INVIS($zero)
#	li $a0, 1
#	sw $a0, 0($t0)	# go to invis_state 1
#	j interrupt_dispatch
###
###	
#invis_state1:
#	mfc0 $a1, $13
#	and $a0, $a1, INVIS_MASK
#	beq $zero, $a0, interrupt_dispatch 	# if we can't call another insibility interrupt
###									# go back to interrupt dispatch
#	sw  $zero, INVIS_ACKNOWLEDGE($zero)
#	sw 	$zero, ACTIVATE_INVIS($zero)
##
  	j	interrupt_dispatch	# see if other interrupts are waiting

timer_interrupt:
	sw	$a1, TIMER_ACKNOWLEDGE($zero)	# acknowledge interrupt
	sw $a1, PICK_FLAG($zero)


#	la 	$a0, target_x
#	lw 	$a0, 0($a0)
#	
#	la 	$a1, target_y
#	lw 	$a1, 0($a1)
#
#	lw $t0, BOT_X($zero)
#	lw $t1, BOT_Y($zero)	## get my location
#
#	sub $a0, $a0, $t0
#	sub $a1, $a1, $t1		# get x and y differences
#
#	jal euclidean_dist		# find euclidean distance away
#	bgt $v0, 50, next  # if we're greater then 10 units away, no worries
#
#	# else, check what invis_state we're in ( a. we've never called it before or b. we have and we're at the behest of the invis interrupt), go invisible and continue collecting flags
#	
#	la 	$t0, invis_state
#	lw 	$a0, 0($t0)
#	bne $a0, $zero, invis_state1
#invis_state0:
#	sw $zero, ACTIVATE_INVIS($zero)
#	li $a0, 1
#	sw $a0, 0($t0)	# go to invis_state 1
#	j next
###
###	
#invis_state1:
#	mfc0 $a1, $13
#	and $a0, $a1, INVIS_MASK
#	beq $zero, $a0, interrupt_dispatch 	# if we can't call another insibility interrupt
###									# go back to interrupt dispatch
#	sw  $zero, INVIS_ACKNOWLEDGE($zero)
#	sw 	$zero, ACTIVATE_INVIS($zero)
##
next:
	
	lw $a0, FLAGS_IN_HAND($zero)
	li $a1, 3 
	blt $a0, $a1, getting_flags_logic
	jal go_home
	j request_timer
getting_flags_logic:
	la $k0, flags
	sw $k0, FLAG_REQUEST($zero)  # finds the nearest flag and goes to that one
	lw $a0, 160($k0) # look 3 flags ahead
	li $t0, -1
	beq $a0, $t0, generate_flag
find_closest:
	lw $a1, 4($k0)
	lw $a0, 0($k0)	# setup first flag's x and y
	

	# now $a0 contains a flag's x coord and $a1 contains a flag's y coord
	# let's find it's euclidean distance from the bot and consider that the minimum distance of the bot to a flag
	# then do a findmin over the available flags

	sub $sp, $sp, 24  		## grab some stack space to store min_dist and best x and y coords
    sw 	$a0, 0($sp)		## best x
	sw 	$a1, 4($sp)		## best y
	sw 	$s0, 12($sp)
	sw 	$s1, 16($sp)
	sw 	$s2, 20($sp)
		
	lw 	$t0, BOT_X($zero)
	lw	$t1, BOT_Y($zero) ## my bot's x, y

	sub $a0, $a0, $t0
	sub $a1, $a1, $t1	## get x difference and y difference
	
	jal euclidean_dist
	sw  $v0, 8($sp)		## arbitrarily consider distance to first available flag the minumum distance for now
	
	# iterate through 4 of the next available flags while checking that they exist
	la  $s0, flags
	add $s0, $s0, 8		# jump over the first available flag to look at the rest of the list
check_better:
	lw 	$s1, 0($s0) 	# load next available x 
	lw 	$s2, 4($s0) 	# load next available y
    blt $s2, $zero, go_to_closest # if we've reached the -1s, we know we're out of flags to investigate so go to the closest
	lw	$a0, BOT_X($zero)
	lw 	$a1, BOT_Y($zero)	# get current x and y of bot
	sub $a0, $a0, $s1
	sub $a1, $a1, $s2
	jal euclidean_dist
	lw 	$t3, 8($sp)		# is new dist < min_dist?
	bgt $v0, $t3, next_flag
	sw 	$v0, 8($sp)		## if so, store new_dist, best x, and best_y
	sw 	$s1, 0($sp)
	sw  $s2, 4($sp)
next_flag:
	add $s0, $s0, 8
	j check_better	

go_to_closest:
	
	lw $a0, 0($sp) 	# grab best x
	lw $a1, 4($sp) 	# grab best y

	# restore stack
                  
    lw  $s0, 12($sp)
    lw  $s1, 16($sp)
    lw  $s2, 20($sp)
    add $sp, $sp, 24      

	jal goto_point

request_timer:
	lw	$v0, TIMER	# current time
	add	$v0, $v0, 2000
	sw	$v0, TIMER	# request timer 
	j	interrupt_dispatch	# see if other interrupts are waiting

generate_flag:
	li $t0, 7	
	lw $a0, ENERGY($zero)
	blt $a0, $t0, out_of_energy
more_flags:
	sw $t0, GENERATE_FLAG($zero)
	lw $a0, ENERGY($zero)
	bgt $a0, 7, more_flags 	# generate as many flags as possible at the moment
	
	j getting_flags_logic
out_of_energy:
	lw $t0, 0($k0) # are there any flags left on the board?	
	blt $t0, $zero, home # 	if not, head home
	j find_closest			# if so, find them
home:
	jal go_home
	j timer_interrupt
		
bonk_interrupt:
	sw $a1, BONK_ACKNOWLEDGE

#If we hit a wall, then we are turning 180 and heading in that direction.
#We can change this later.
	li $a0, 180
	sw $a0, ANGLE($zero)
	sw $zero, ANGLE_CONTROL($zero)
	li $a0, 10
	sw $a0, VELOCITY($zero)

	j interrupt_dispatch

invis_interrupt:						# TODOL make this actually do things
	sw $a1, INVIS_ACKNOWLEDGE($zero)

#    lw $t0, BOT_X($zero)
#    lw $t1, BOT_Y($zero)    ## get my location
#
#	
#
#	# set a counter to scan whether or not our bot is getting closer to the last location
#	# of the competitor
#	li 	$t2, 0
#	
#
#	# scan whether we're getting closer to last location of competitor
#rescan:
#	bgt $t2, 10, interrupt_dispatch 
#	la 	$a0, target_x
#	lw 	$a0, 0($a0)
#	
#	la 	$a1, target_y
#	lw 	$a1, 0($a1)
#	
#    sub $a0, $a0, $t0
#    sub $a1, $a1, $t1       # get x and y differences
#
#    jal euclidean_dist      # find euclidean distance away
#
#	add $t2, $t2, 1 		# increment counter
#    bgt $v0, 100, rescan
#	
#   
#	
#    sw  $zero, ACTIVATE_INVIS($zero)
#
    j   interrupt_dispatch  # see if other interrupts are waiting



tag_interrupt:							# TODO: make this actually do things
	sw $a1, TAG_ACKNOWLEDGE($zero)
	j interrupt_dispatch

non_intrpt:	# was some non-interrupt
	li	$v0, PRINT_STRING
	la	$a0, non_intrpt_str
	syscall	# print out an error message
	# fall through to done

go_home:
	sub $sp, $sp, 4
	sw $ra, 0($sp)
	li $a0, BASE_X
	li $a1, BASE_Y
	jal goto_point
	lw $ra, 0($sp)
	add $sp, $sp, 4
	jr $ra

	
goto_point:						#Take $a0 = destination x and $a1 = destination y and sets Spimbot on a crash
	sub $sp, $sp, 4				# course in that direction. YAY!
	sw $ra, 0($sp)
	jal find_angle_to_point
	sw $v0, ANGLE($zero)
	add $t0, $zero, 1
	sw $t0, ANGLE_CONTROL($zero)
	lw $ra, 0($sp)
	add $sp, $sp, 4
	jr $ra
	

find_angle_to_point:  					#So this function takes $a0 = destination x and $a1 = destination y 
	lw $t0, BOT_X($zero)		  	  # and returns $v0 = absolute angle needed to get to that point
	lw $t1, BOT_Y($zero)
	sub $a0, $a0, $t0
	sub $a1, $a1, $t1
	move $s0, $ra
	jal sb_arctan
	move $ra, $s0
	jr $ra

#THIS IS ALL THE EUCLIDEAN STUFF I COPIED

# -----------------------------------------------------------------------
# sb_arctan - computes the arctangent of y / x
# $a0 - x
# $a1 - y
# returns the arctangent
# -----------------------------------------------------------------------

sb_arctan:
	li	$v0, 0		# angle = 0;

	abs	$t0, $a0	# get absolute values
	abs	$t1, $a1
	ble	$t1, $t0, no_TURN_90	  

	## if (abs(y) > abs(x)) { rotate 90 degrees }
	move	$t0, $a1	# int temp = y;
	neg	$a1, $a0	# y = -x;      
	move	$a0, $t0	# x = temp;    
	li	$v0, 90		# angle = 90;  

no_TURN_90:
	bgez	$a0, pos_x 	# skip if (x >= 0)

	## if (x < 0) 
	add	$v0, $v0, 180	# angle += 180;

pos_x:
	mtc1	$a0, $f0
	mtc1	$a1, $f1
	cvt.s.w $f0, $f0	# convert from ints to floats
	cvt.s.w $f1, $f1
	
	div.s	$f0, $f1, $f0	# float v = (float) y / (float) x;

	mul.s	$f1, $f0, $f0	# v^^2
	mul.s	$f2, $f1, $f0	# v^^3
	l.s	$f3, three	# load 5.0
	div.s 	$f3, $f2, $f3	# v^^3/3
	sub.s	$f6, $f0, $f3	# v - v^^3/3

	mul.s	$f4, $f1, $f2	# v^^5
	l.s	$f5, five	# load 3.0
	div.s 	$f5, $f4, $f5	# v^^5/5
	add.s	$f6, $f6, $f5	# value = v - v^^3/3 + v^^5/5

	l.s	$f8, PI		# load PI
	div.s	$f6, $f6, $f8	# value / PI
	l.s	$f7, F180	# load 180.0
	mul.s	$f6, $f6, $f7	# 180.0 * value / PI

	cvt.w.s $f6, $f6	# convert "delta" back to integer
	mfc1	$t0, $f6
	add	$v0, $v0, $t0	# angle += delta

	jr 	$ra
	

# -----------------------------------------------------------------------
# euclidean_dist - computes sqrt(x^2 + y^2)
# $a0 - x
# $a1 - y
# returns the distance
# -----------------------------------------------------------------------

euclidean_dist:
	mul	$a0, $a0, $a0	# x^2
	mul	$a1, $a1, $a1	# y^2
	add	$v0, $a0, $a1	# x^2 + y^2
	mtc1	$v0, $f0
	cvt.s.w	$f0, $f0	# float(x^2 + y^2)
	sqrt.s	$f0, $f0	# sqrt(x^2 + y^2)
	cvt.w.s	$f0, $f0	# int(sqrt(...))
	mfc1	$v0, $f0
	jr	$ra

done:
	la	$k0, chunkIH
	lw	$a0, 0($k0)	# Restore saved registers
	lw	$a1, 4($k0)
	lw $v0, 8($k0)
	lw $t0, 12($k0)
	lw $t1, 16($k0)
	lw $v0, 20($k0)
	lw $s0, 24($k0)
	lw $ra, 28($k0)
	lw $t2, 32($k0)
    lw $t3, 36($k0)



.set noat
	move	$at, $k1	# Restore $at
.set at
	eret

