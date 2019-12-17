; VMEM 0 should have these as the first two entries
; 0007
; 000c

com
bz $7, 2
sys
jerr $0, 2
add $1, 1
fail 2
sys
com
jerr $1, 1
sub $1, 1
ex  $1, $0
dup $0, $5
fail 8
