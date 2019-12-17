com
bz $7, 2
sys
jerr $0, 2
add $1, 1
fail 2
sys
com
jerr $1, 1
jerr $1, 2
bz $7, 2
sys
land
ex  $1, $0
dup $0, $5
fail 8
sys
; VMEM 0 should have these as the first two entries
; 0007
; 000e