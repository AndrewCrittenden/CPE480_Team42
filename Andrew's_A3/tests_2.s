com
bz $7, 2 ; This branch jumps over a sys which is designed to halt instructions that run in reverse past this point
sys
jerr $0, 2 ; Check for SIGTMV, If in reverse then jump to line 7, com
add $1, 1
fail 2 ; Fail due to SIGTMV, begin reverse
sys
com
jerr $1, 1
jerr $1, 2 ;Test when jerr passes through in reverse
bz $7, 2
sys
land ; test land restoring from undo stack
ex  $1, $0 ; test SIGILL exchange
dup $0, $5
fail 8 ;test fail as a halt

; VMEM 0 should have these as the first two entries
; 0007
; 000e