.data

# spimbot constants
NUM_FLAGS   = 40	# maximum flags you can ever have on the board
BASE_RADIUS = 24
MAX_FLAGS   = 5		# maximum flags you can have in hand (might not be optimal though)
FLAG_COST   = 7
INVIS_COST  = 25

# memory-mapped I/O
VELOCITY           = 0xffff0010
ANGLE              = 0xffff0014
ANGLE_CONTROL      = 0xffff0018
BOT_X              = 0xffff0020
BOT_Y              = 0xffff0024
FLAG_REQUEST       = 0xffff0050
PICK_FLAG          = 0xffff0054
FLAGS_IN_HAND      = 0xffff0058
GENERATE_FLAG      = 0xffff005c
ENERGY             = 0xffff0074
ACTIVATE_INVIS     = 0xffff0078 
PRINT_INT          = 0xffff0080
PRINT_FLOAT        = 0xffff0084
PRINT_HEX          = 0xffff0088
SUDOKU_REQUEST     = 0xffff0090
SUDOKU_SOLVED      = 0xffff0094
OTHER_BOT_X        = 0xffff00a0
OTHER_BOT_Y        = 0xffff00a4
COORDS_REQUEST     = 0xffff00a8
SCORE              = 0xffff00b0
ENEMY_SCORE        = 0xffff00b4

# interrupt memory-mapped I/O
TIMER              = 0xffff001c
BONK_ACKNOWLEDGE   = 0xffff0060
COORDS_ACKNOWLEDGE = 0xffff0064
TIMER_ACKNOWLEDGE  = 0xffff006c
TAG_ACKNOWLEDGE    = 0xffff0070
INVIS_ACKNOWLEDGE  = 0xffff007c

# interrupt masks
TAG_MASK           = 0x400
INVIS_MASK         = 0x800
BONK_MASK          = 0x1000
COORDS_MASK        = 0x2000
TIMER_MASK         = 0x8000

# syscall constants
PRINT_STRING = 4
PRINT_CHAR = 11

.text
main:
	li	$t4, TIMER_MASK		# timer interrupt enable bit
	or	$t4, $t4, COORDS_MASK # coords interrupt bit
	or	$t4, $t4, BONK_MASK   # bonk interrupt bit
	or	$t4, $t4, INVIS_MASK	#invis interrupt bit
	or	$t4, $t4, TAG_MASK 		#tag interrupt bit
	or	$t4, $t4, 1		# global interrupt enable
	mtc0	$t4, $12		# set interrupt mask (Status register)
	jr	$ra


kdata				# interrupt handler data (separated just for readability)
chunkIH:	.space 166666	
non_intrpt_str:	.asciiz "Non-interrupt exception\n"
unhandled_str:	.asciiz "Unhandled interrupt type\n"


.ktext 0x80000180
interrupt_handler:
.set noat
	move	$k1, $at		# Save $at                               
.set at
	la	$k0, chunkIH
	sw	$a0, 0($k0)		# Get some free registers                  
	sw	$a1, 4($k0)		# by storing them to a global variable     
	sw $v0, 8($k0)
	sw $t0, 12($k0)

	mfc0	$k0, $13		# Get Cause register                       
	srl	$a0, $k0, 2                
	and	$a0, $a0, 0xf		# ExcCode field                            
	bne	$a0, 0, non_intrpt         

interrupt_dispatch:			# Interrupt:                             
	mfc0	$k0, $13		# Get Cause register, again                 
	beq	$k0, 0, done		# handled all outstanding interrupts     

	and	$a0, $k0, COORDS_MASK
	bne	$a0, 0, coords_interrupt

	and	$a0, $k0, TIMER_MASK	# is there a timer interrupt?
	bne	$a0, 0, timer_interrupt

	li	$v0, PRINT_STRING	# Unhandled interrupt types
	la	$a0, unhandled_str
	syscall 
	j	done

coords_interrupt:
	sw $a1, COORDS_ACKNOWLEDGE
	sw $a1, COORDS_REQUEST
	
	lw $s0, OTHER_BOT_X($zero)
	lw $s1, OTHER_BOT_Y($zero)

	j	interrupt_dispatch	# see if other interrupts are waiting

timer_interrupt:
	sw	$a1, TIMER_ACKNOWLEDGE	# acknowledge interrupt

	lw $a0, BOT_Y
	bne $a0, $s1, not_equal
	sw $zero, VELOCITY
	j request_timer
not_equal:
	slt $t0, $s1, $a0
	mul $t0, $t0, 180
	add $t0, $t0, 90
	sw $t0, ANGLE
	li $t0, 1
	sw $t0, ANGLE_CONTROL
	li $t0, 10
	sw $t0, VELOCITY
request_timer:
	lw	$v0, TIMER		# current time
	add	$v0, $v0, 2000  
	sw	$v0, TIMER		# request timer in 50000 cycles

	j	interrupt_dispatch	# see if other interrupts are waiting

non_intrpt:				# was some non-interrupt
	li	$v0, PRINT_STRING
	la	$a0, non_intrpt_str
	syscall				# print out an error message
	# fall through to done

done:
	la	$k0, chunkIH
	lw	$a0, 0($k0)		# Restore saved registers
	lw	$a1, 4($k0)
	lw $v0, 8($k0)
	lw $t0, 12($k0)
.set noat
	move	$at, $k1		# Restore $at
.set at 
	eret
