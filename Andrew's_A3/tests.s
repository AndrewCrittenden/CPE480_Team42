; this test should take 91955 simulation time units (~9195 clocks)

; use [fail mask] instruction as fail command. cycle through the 16 possible
; mask values so that when reviewing the debug output, the particular fail
; instruction responsible is easier to find (the mask will show in sXsrc)

l16 $15, 0 ; tests passed count

; nops (in this project)
; jerr $0, 1
com

; test l16
l16 $0, 0xAAAA
l16 $1, 0x5555
or  $0, $1
add $0, 1
bz  $0, 2
fail 0
add $15, 1

; test xhi and lhi
l16 $2, 0
xhi $2, 0x12
lhi $3, 0x12
sub $2, $3
bz  $2, 2
fail 1
add $15, 1

; test xlo and llo, high bit 0
l16 $4, 0
xlo $4, 0x72
llo $5, 0x72
sub $4, $5
bz  $4, 2
fail 2
add $15, 1

; test xlo and llo, high bit 1
l16 $4, 0
xlo $4, 0x82
llo $5, 0x82
sub $4, $5
bnz $4, 2
fail 3
llo $6, 127
sub $4, $6
sub $4, $6
sub $4, 2
bz  $4, 2
fail 4
add $15, 1

; test add, bnz, bz, bnn, bn +imm
l16 $0, 0
add $0, 7
bnn $0, 2
fail 5
bnz $0, 2
fail 6
add $0, 9 ; -7
bz  $0, 2
fail 7
add $0, -7
bn  $0, 2
fail 8
bnz $0, 2
fail 9
add $15, 1

; test sub, bnz, bz, bnn, bn +imm
l16 $1, 0
sub $1, 7
bn  $1, 2
fail 10
bnz $1, 2
fail 11
sub $1, 9 ; -7
bz  $1, 2
fail 12
sub $1, -7
bnn $1, 2
fail 13
bnz $1, 2
fail 14
add $15, 1

; test xor
l16 $2, 53
l16 $3, 132
l16 $4, 177
xor $2, $3
sub $2, $4
bz  $2, 2
fail 15
add $15, 1

; test rol, no rollover
l16 $9, 23
l16 $10, 736
rol $9, 5
sub $9, $10
bz  $9, 2
fail 0
add $15, 1

; test rol, rollover
l16 $9, 9054
l16 $10, 48198
rol $9, 9 ; 9 should be treated as unsigned
sub $9, $10
bz  $9, 2
fail 1
add $15, 1

; test shr, high bit 0
l16 $0, 0x4511
llo $1, 0x45
shr $0, 8
sub $0, $1
bz  $0, 2
fail 2
add $15, 1

; test shr, high bit 1
l16 $0, 0x8920
l16 $1, 0xF124
shr $0, 3
sub $1, $0
bz  $1, 2
fail 3
add $15, 1

; test or
l16 $11, 0x03CF
l16 $12, 0x5555
l16 $13, 0x57DF
or  $11, $12
sub $11, $13
bz  $11, 2
fail 4
add $15, 1

; test and
l16 $0, 0x6914
l16 $1, 0xAAAA
l16 $2, 0x2800
and $0, $1
sub $0, $2
bz  $0, 2
fail 5
add $15, 1

; test dup
l16 $4, 0x0987
dup $5, $4
sub $5, $4
bz  $5, 2
fail 6
add $15, 1

; test xor, and
l16 $5, 0x2197
l16 $6, 0xFFFF
l16 $7, 0xDE68
xor $6, $5
sub $7, $6
bz  $7, 2
fail 7
and $5, $6
bz  $5, 2
fail 8
add $15, 1

; test jnz, jnn, j, jz register minefield
	l16 $1, 0
	l16 $2, 1
	l16 $3, -1
	l16 $4, tjrm2
	l16 $5, tjrm3
	l16 $6, tjrm4
	l16 $7, tjrm5
	l16 $8, tjrmf
	jz $1, $4  ; 1st
tjrmf:  fail 9
	fail 10
tjrm3:  jnn $1, $7 ; 3rd
	fail 11
	fail 12
tjrm4:  jn $3, $6  ; 4th
	fail 13
	fail 14
tjrm2:  jnz $3, $5 ; 2nd
	fail 15
	fail 0
tjrm5:  jnz $1, $8 ; 5th -- these should all fail
	jnn $3, $8
	jn  $2, $8
	jz  $3, $8
	add $15, 1

; test undo stack general usage
l16 $2, 5
l16 $3, 0xA85
l16 $4, 4
l16 $5, 7
l16 $6, 7
l16 $7, 3
l16 $8, 0xFF80
l16 $9, 0x100
l16 $1, 5
l16 $1, 0xA85 ; u: 5
and $1, 6     ; u: 0xA85 5
or  $1, 3     ; u: 4 0xA85 5
dup $1, $1    ; u: 7 4 0xA85 5
shr $1, 1     ; u: 7 7 4 0xA85 5
llo $1, 128   ; u: 3 7 7 4 0xA85 5
lhi $1, 1     ; u: 0xFF80 3 7 7 4 0xA85 5
dup $1, 1     ; u: 0x100 0xFF80 3 7 7 4 0xA85 5
sub $2, 7$
bz  $2, 2
fail 1
sub $3, 6$
bz  $3, 2
fail 2
sub $4, 5$
bz  $4, 2
fail 3
sub $5, 4$
bz  $5, 2
fail 4
sub $6, 3$
bz  $6, 2
fail 5
sub $7, 2$
bz  $7, 2
fail 6
sub $8, 1$
bz  $8, 2
fail 7
sub $9, 0$
bz  $9, 2
fail 8
add $15, 1

; test undo stack wrap around
l16 $1, 0
dup $0, 1
dup $0, 3
dup $0, 7
dup $0, 2
dup $0, 5
dup $0, 4
dup $0, 0
dup $0, 6
dup $0, 0
dup $0, 4
dup $0, 3
dup $0, 5
dup $0, 1
dup $0, 2
dup $0, 6
dup $0, 7
dup $0, 4
add $1, 2$
sub $1, 2 ; index 2 back on the undo stack should be the number 2
bz  $1, 2
fail 9
add $15, 1

; test read/write to undo stack in same instruction
llo $0, 4  ; $0: 4, u: x
llo $0, 5  ; $0: 5, u: 4 x
llo $0, 6  ; $0: 6, u: 5 4 x
dup $0, 1$ ; $0: 4, u: 6 5 4 x
dup $1, 0$ ; $1: 6, u: x 6 5 4 x
sub $0, 4
bz  $0, 2
fail 10
sub $1, 6
bz  $1, 2
fail 11
llo $0, 4
llo $1, 5
llo $2, 6 ; u: x x x x 6 5 4 x
sub $0, 6$
sub $1, 5$
sub $2, 4$
bnz $0, 3
bnz $1, 2
bz  $2, 2
fail 12
add $15, 1

; test basic land
	l16 $0, tbl0
tbl0:   bnz $0, 5 ; always passes
	fail 10
	fail 11
	fail 12
	fail 13
	land      ; should push value same as $0 to undo stack
	sub $0, 0$
	bz  $0, 2
	fail 14
	add $15, 1

; test minefield land
	l16 $1, tml1
	l16 $2, tml2
	l16 $3, tml3
	l16 $4, tml4
	l16 $0, 0
tml1:   bz  $0, 5 ; 1st
	fail 15
	land
tml3:   bz $0, 6  ; 3rd
	fail 1
	land
tml2:   bz $0, -4 ; 2nd
	fail 2
	fail 3
	land
tml4:   bz $0, 2  ; 4th
	fail 4
tml5:   land      ; 5th
	sub $4, 0$ ; should all become 0
	sub $3, 1$
	sub $2, 2$
	sub $1, 3$
	or  $1, $2
	or  $1, $3
	or  $1, $4
	bz  $1, 2  ; checks if any are not 0
	fail 5
	add $15, 1

; test land without jumps
	l16 $0, land_without_jmp_lastpc
land_without_jmp_lastpc:
	or  $1, $2 ; any instruction
	land
	sub $0, 0$
	bz $0, 2
	fail 6
add $15, 1

; test land mixed jumps no jumps
lm0:    llo $0, 0  ; 0th
	land
lm1:    bz  $0, 3  ; 1st (always)
	land
lm4:    bz  $0, 5  ; 4th (always)
	land
lm2:    bnz $0, -5 ; 2nd (never)
	land
lm3:    bz  $0, -5 ; 3rd (always)
	land
lm5:    bnz $0, -3 ; 5th (never)
	land
dup $11, 0$ ; 5th
dup $10, 2$ ; 4th
dup $9,  4$ ; 3rd
dup $8,  6$ ; 2nd
dup $7,  8$ ; 1st
dup $6,  10$; 0th
l16 $0, lm0
l16 $1, lm1
l16 $2, lm2
l16 $3, lm3
l16 $4, lm4
l16 $5, lm5
sub $0, $6
sub $1, $7
sub $2, $8
sub $3, $9
sub $4, $10
sub $5, $11
bnz  $0, 6
bnz  $1, 5
bnz  $2, 4
bnz  $3, 3
bnz  $4, 2
bz   $5, 2
fail 7
add $15, 1

; loop test
add $3, 5
add $3, -1
bnn $3, -1
l16 $4, -1
sub $3, $4
bz  $3, 2
fail 6
add $15, 1

.data
.origin 0x0000
.word   0x5cd7
.word   0xc93a
.word   0x006b
.word   0x001a
.word   0xe899
.text

; arithmetic memory read test
l16 $0, 0
l16 $1, 1
l16 $2, 2
l16 $3, 3
l16 $4, 4
dup $0, @$0 ; should contain 0x5cd7
add $0, @$1 ; should contain 0xc93a ; =0x2611
xor $0, @$2 ; should contain 0x006b ; =0x267a
rol $0, @$3 ; should contain 0x001a ; =0xe899
sub $0, @$4 ; should contain 0xe899 (the result)
bz  $0, 2
fail 7
add $15, 1

; memory write test
l16 $0, 0
l16 $1, 1
l16 $2, 2
l16 $3, 3
l16 $4, 4
l16 $5, 0xF24B
ex  $5, @$0 ; $5:=0x5cd7, @$0:=0xf24b
ex  $5, @$1 ; $5:=0xc93a, @$1:=0x5cd7
ex  $5, @$2 ; $5:=0x006b, @$2:=0xc93a
ex  $5, @$3 ; $5:=0x001a, @$3:=0x006b
ex  $5, @$4 ; $5:=0xe899, @$4:=0x001a
l16 $6,  0xF24B
l16 $7,  0x5CD7
l16 $8,  0xC93A
l16 $9,  0x006B
l16 $10, 0x001A
l16 $11, 0xE899
sub $6, @$0  ; check all values against known correct
sub $7, @$1
sub $8, @$2
sub $9, @$3
sub $10, @$4
sub $11, $5
or  $6, $7
or  $6, $8
or  $6, $9
or  $6, $10
or  $6, $11
bz  $6, 2
fail 8
add $15, 1

.data
.word 0x010e
.word 0x785c
.word 0xf6a4
.word 0x7ee4
.word 0xf4cc
.word 0x8fa1
.word 0x0a4e
.word 0x5d3f
.word 0x974b
.word 0xf6a4
.text

; signed-comparison insertion sort
; memory indices 5-14 should have the array (in any order, of course)
; 010e 785c f6a4 7ee4 f4cc 8fa1 0a4e 5d3f 974b f6a4
; final order should be
; 8fa1 974b f4cc f6a4 f6a4 010e 0a4e 5d3f 785c 7ee4
	l16 $0, 5  ; start addr
	l16 $1, 10 ; length
	l16 $2, 1  ; i
	l16 $3, 0  ; j
	l16 $14, sa_loop_outer_begin
	l16 $13, sa_loop_inner_test
	l16 $12, sa_loop_inner_end
	l16 $11, sa_loop_outer_test
	; begin
	jnz $14, $11 ; unconditional
sa_loop_outer_begin:
	land
	dup $3, $2 ; j := i
sa_loop_inner_test:
	land
	; done if j == 0
	jz $3, $12
	; get arr[j], arr[j-1]
	dup $4, $0 ; $4 := j
	add $4, $3
	dup $5, $4 ; $5 := j-1
	sub $5, 1
	dup $7, @$4 ; $7 := arr[j]
	dup $6, @$5 ; $6 := arr[j-1]
	; to do signed comparison, need to compute ALU flags like a "real" CPU
	; would. the comparison being made (from insertion sort algorithm) is:
	; swap if arr[j] < arr[j-1], therefore jump if arr[j] >= arr[j-1].
	; "greater than or equal", using ARM-style flags, is N==V of the
	; operation (arr[j] - arr[j-1]). So do the subtract and compute V with:
	; (A[j][15] & (~A[j-1][15]) & (~N)) | ((~A[j][15]) & A[j-1][15] & N)
	; but optimized to use less registers because there aren't many free...
	; $8 = sub = arr[j] - arr[j-1]
	dup $8, $7
	sub $8, $6
	; $7 = ~arr[j][15] = ~((arr[j] >> 15) & 1)
	shr $7, 15
	and $7, 1
	xor $7, 1
	; $6 = arr[j-1][15] = ((arr[j-1] >> 15) & 1)
	shr $6, 15
	and $6, 1
	; $8 = N = ((sub >> 15) & 1)
	shr $8, 15
	and $8, 1
	; $9 = v1 = ~((~arr[j][15]) | arr[j-1][15] | N)
	dup $9, $7
	or  $9, $6
	or  $9, $8
	xor $9, 1
	; $10 = v2 = ((~arr[j][15]) & arr[j-1][15] & N)
	dup $10, $7
	and $10, $6
	and $10, $8
	; $10 = V = (v1 | v2)
	or $10, $9
	; jmp if N (sub) == V
	sub $8, $10
	bz  $8, $12
	; swap at A[j] and A[j-1]
	ex  $6, @$4 ; $6 <- arr[j],   arr[j]   -> garbage
	ex  $6, @$5 ; $6 <- arr[j-1], arr[j-1] -> arr[j]
	ex  $6, @$4 ; $6 <- garbage,  arr[j]   -> arr[j-1]
	; loop
	sub $3, 1 ; j--
	jnz $14, $13 ; unconditional
sa_loop_inner_end:
	land
	add $2, 1 ; i++
sa_loop_outer_test:
	land
	dup $6, $2
	sub $6, $1 ; jmp if i < length: jmp if i ($6) - length ($1) < 0
	jn  $6, $14
	; done

; check array is sorted
l16 $2, 0x8FA1
ex  $3, @$0 ; $0 is start addr
sub $3, $2
bz  $3, 2
fail 8
add $0, 1
l16 $2, 0x974B
ex  $3, @$0
sub $3, $2
bz  $3, 2
fail 9
add $0, 1
l16 $2, 0xF4CC
ex  $3, @$0
sub $3, $2
bz  $3, 2
fail 10
add $0, 1
l16 $2, 0xF6A4
ex  $3, @$0
sub $3, $2
bz  $3, 2
fail 11
add $0, 1
l16 $2, 0xF6A4
ex  $3, @$0
sub $3, $2
bz  $3, 2
fail 12
add $0, 1
l16 $2, 0x010E
ex  $3, @$0
sub $3, $2
bz  $3, 2
fail 13
add $0, 1
l16 $2, 0x0A4E
ex  $3, @$0
sub $3, $2
bz  $3, 2
fail 14
add $0, 1
l16 $2, 0x5D3F
ex  $3, @$0
sub $3, $2
bz  $3, 2
fail 15
add $0, 1
l16 $2, 0x785C
ex  $3, @$0
sub $3, $2
bz  $3, 2
fail 0
add $0, 1
l16 $2, 0x7EE4
ex  $3, @$0
sub $3, $2
bz  $3, 2
fail 1
add $15, 1

; some tests from the previous project
l16     $1, 1
add     $1, 1 ; test add
xor     $1, 2
bz      $1, 2
fail 2
l16     $1, 0
add     $1, 2
sub     $1, 1 ; test sub
xor     $1, 1
bz      $1, 2
fail 3
l16     $1, 0
add     $1, 1
and     $1, 1 ; test and
xor     $1, 1
bz      $1, 2
fail 4
l16     $2, 0
add     $2, 1
dup     $1, $2 ; test dup
xor     $1, 1
bz      $1, 2
fail 5
l16     $1, 0
sub     $1, 1 ; test bn & bnn
bnn     $1, 2
bn      $1, 2
fail 6
and     $1, 0
or      $1, 1 ; test or
xor     $1, 1
bz      $1, 2
fail 7
l16    $5, 0
add    $5, 2
shr    $5, 1
xor    $5, 1
bz     $5, 2
fail 8
l16    $5, 0
add    $5, 1
rol    $5, 1
xor    $5, 2
bz     $5, 2
fail 9
add $15, 1

; make sure every test passed
l16 $14, 28 ; num tests
sub $15, $14
bz  $15, 2
fail 9
sys
