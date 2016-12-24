.model small

.code
ORG 100h
S:
pop [bp+di+584h]
add word ptr [di+51h], 5154h
sub byte ptr [bx+si+0F6h], 82h
cmp word ptr ds:[565Ah], 0F89Fh
add si, 0214h
add si, 24h
add al, 02h
add si, 9Fh
sub si, 0214h
sub si, 24h
sub al, 02h
sub si, 9Fh
cmp si, 0F214h
cmp si, 24h
cmp al, 02h
cmp si, 9Fh
mov word ptr [si], 0214h
mov word ptr [si], 24h
mov byte ptr [si], 02h
mov word ptr [si], 9Fh ;---
inc word ptr [bx+si]
dec byte ptr [bp+254h]
mul al
mul di
div word ptr [bp+si+0F4h]
call [bx+di]
call ss:[bx+54h] 
jmp [bp+si+0F54h]
jmp es:[di]
push [si] ;--------------------
mov ax, ds:[0542h]
mov al, ds:[0F965h]
mov ds:[9845h], ax
mov ds:[0EF98h], al;---------------------
blabla db 09Ah, 54h, 0F8h, 98h, 0EFh
blablb db 0EAh, 0E4h, 0F8h, 78h, 04Fh
ja cs:[01E0h]
loop cs:[150h]
aa  db 0E8h, 98h, 41h
bb  db 0E9h, 0FFh, 98h
int 5
int 16
int 21h
ret
ret 45h
ret 0F465h
add ax, 64h
sub bl, 0CFh
mov dh, 89h
mov cx, 0F874h ;-------
add al, [bx+si]
cmp bx, [bp+si+541h]
mov ds, ax
mov es, [bx+di]
mov [di], ss ;----
add al, bl
or [bx], bx
adc dx, [si+052h]
sbb bl, [bp+di]
sub ax, bx
and bl, ds:[0FFh]
xor [bx+si+5487h], dh ;--------
or ax, 5487h
adc al, 0B5h
sbb ax, 0FFFFh
and al, 5
xor ax, 54h
test ax, 874h
retf 5487h ;-----------
daa
das
aaa
aas
nop
cbw
cwd
wait
pushf
popf
sahf
lahf
movsb
movsw
cmpsb
cmpsw
stosb
stosw
lodsb
lodsw
scasb
scasw
retf
int 3 
into
iret
xlat
lock
repnz
rep
hlt
cmc
ret
clc
stc
cli
sti
cld
std
add word ptr ss:[si], bx
mov ch, es:[bx+di+0F484h] ;-----
or ch, 54h
adc bx, 7582h
sbb word ptr [bp+004Fh], 22h
and word ptr cs:[di], 0BBh
xor byte ptr [bx+si], 94h ;---
loopne cs:[020Dh]
loope cs:[020Eh] ;----
not word ptr ss:[di]
neg ax
imul byte ptr ds:[0FFh]
idiv cl ;--------------------
test ax, ds:[bp]
xchg bl, dh
lea bx, cs:[bx+si+54h]
les cx, ds:[541h]
lds ax, [bx+di]
rol ax, 1
rol ax, cl
ror byte ptr cs:[bp+si], 1
rcr dl, cl
shl word ptr [bx], 1
shr word ptr [si], cl
sal byte ptr [bx+0254h], 2
sar cx, cl
rcl bx, 2 ;----------
xchg ax, ax
xchg dx, ax
xchg ax, si
test word ptr cs:[bp+si+054h], 98h
add word ptr cs:[bx+di], 0FF98h
cmp ss:[bx+0105h], 0804h
int 48h
in al, 48h
in ax, 0F7h
out 64h, al
out 88h, ax
aam
aad







END S