.data
symbollist: .ascii  "0123456789ABCDEFG"

hard_board:
.half  65535     1  2048  1024 65535 65535   128 65535 65535 16384 65535 65535  4096 32768  8192 65535
.half  65535 16384 65535 65535  2048 65535 65535 65535 65535 65535 65535     4 65535 65535     2 65535
.half      4 65535 65535 65535    16 65535     2   256 32768   128 65535    64 65535 65535 65535   512
.half   8192     2 65535   256 65535 65535 65535 65535 65535 65535 65535 65535     8 65535    64 16384
.half   2048 65535 65535 16384 65535 65535  4096    16     8     4 65535 65535  1024 65535 65535   128
.half  65535 65535     2 65535  8192 65535     8     4  2048  1024 65535     1 65535    32 65535 65535
.half   1024 65535     1     4    32 65535 65535 65535 65535 65535 65535  4096 16384     8 65535  8192
.half  65535  8192     8 65535 65535   128 16384 65535 65535    32   256 65535 65535  4096  2048 65535
.half  65535    64 16384 65535 65535     8  1024 65535 65535 32768  2048 65535 65535   512     4 65535
.half      1 65535  1024  8192     4 65535 65535 65535 65535 65535 65535     8 32768     2 65535  2048
.half  65535 65535     4 65535   512 65535   256  8192  1024     2 65535 16384 65535    16 65535 65535
.half    128 65535 65535    16 65535 65535  2048    32    64  4096 65535 65535  8192 65535 65535     8
.half    256  1024 65535     2 65535 65535 65535 65535 65535 65535 65535 65535    16 65535     1  4096
.half     32 65535 65535 65535     1 65535  8192     8   256    16 65535  1024 65535 65535 65535     4
.half  65535    16 65535 65535    64 65535 65535 65535 65535 65535 65535   128 65535 65535    32 65535
.half  65535     4    64     1 65535 65535    16 65535 65535  2048 65535 65535   128  8192     8 65535

.text
main:
	sub	$sp, $sp, 4
	sw	$ra, 0($sp)

	la	$a0, hard_board
	jal	solve
	la	$a0, hard_board
	jal	print_board

	lw	$ra, 0($sp)
	add	$sp, $sp, 4
	jr	$ra


has_single_bit_set:
	beq	$a0, 0, hsbs_ret_zero	# return 0 if value == 0
	sub	$a1, $a0, 1
	and	$a1, $a0, $a1
	bne	$a1, 0, hsbs_ret_zero	# return 0 if (value & (value - 1)) == 0
	li	$v0, 1
	jr	$ra
hsbs_ret_zero:
	li	$v0, 0
	jr	$ra


get_lowest_set_bit:
	li	$v0, 0			# i
	li	$t1, 1

glsb_loop:
	sll	$t2, $t1, $v0		# (1 << i)
	and	$t2, $t2, $a0		# (value & (1 << i))
	bne	$t2, $0, glsb_done
	add	$v0, $v0, 1
	blt	$v0, 16, glsb_loop	# repeat if (i < 16)

	li	$v0, 0			# return 0
glsb_done:
	jr	$ra


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


get_square_begin:
	# round down to the nearest multiple of 4
	and	$v0, $a0, 0xfffffffc
	jr	$ra


## void 
## solve(unsigned short board[GRID_SQUARED][GRID_SQUARED]) {
##   bool changed;
##   do {
##     changed = rule1(board);
##     changed |= rule2(board);
##   } while (changed);
## }


	
solve:	
	sub $sp, $sp, 4
	sw $ra, 0($sp)

again:	la  $a0, hard_board
	jal 	rule1
	move	$t0, $v0		#store output from rule1
	la		$a0, hard_board
	jal		rule2
	or		$t0, $v0, $t0
	bne $t0, $zero, again
	lw $ra, 0($sp)
	add $sp, $sp, 4
	jr	$ra


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



## bool
## rule2(unsigned short board[GRID_SQUARED][GRID_SQUARED]) {
##   bool changed = false;
##   for (int i = 0 ; i < GRID_SQUARED ; ++ i) {
##     for (int j = 0 ; j < GRID_SQUARED ; ++ j) {
##       unsigned value = board[i][j];
##       if (has_single_bit_set(value)) {
##         continue;
##       }
##       
##       int jsum = 0, isum = 0;
##       for (int k = 0 ; k < GRID_SQUARED ; ++ k) {
##         if (k != j) {
##           jsum |= board[i][k];        // summarize row
##         }
##         if (k != i) {
##           isum |= board[k][j];         // summarize column
##         }
##       }
##       if (ALL_VALUES != jsum) {
##         board[i][j] = ALL_VALUES & ~jsum;
##         changed = true;
##         continue;
##       } else if (ALL_VALUES != isum) {
##         board[i][j] = ALL_VALUES & ~isum;
##         changed = true;
##         continue;
##       }
## 
##       // eliminate from square
##       int ii = get_square_begin(i);
##       int jj = get_square_begin(j);
##       unsigned sum = 0;
##       for (int k = ii ; k < ii + GRIDSIZE ; ++ k) {
##         for (int l = jj ; l < jj + GRIDSIZE ; ++ l) {
##           if ((k == i) && (l == j)) {
##             continue;
##           }
##           sum |= board[k][l];
##         }
##       }
## 
##       if (ALL_VALUES != sum) {
##         board[i][j] = ALL_VALUES & ~sum;
##         changed = true;
##       } 
##     }
##   }
##   return changed;
## }

rule2:
	li	$v0, 0
	jr	$ra

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
	beq		$v0, $zero, r2for2		# continue

	li		$t0, 0					# jsum = 0
	li		$t1, 0					# isum = 0
	li		$t3, 0					# k=-1

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
	jal		get_sqaure_begin
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