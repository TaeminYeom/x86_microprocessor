[org 0x7c00]		; Assembly command
					; Let NASM compiler know starting address of memory
					; BIOS reads 1st sector and copied it on memory address 0x7c00
[bits 16] 			; Assembly command
					; Let NASM compiler know that this code consists of 16its

[SECTION .text] 	; text section

START:				; boot loader(1st sector) starts

    	cli

    	xor ax, ax
    	mov ds, ax
    	mov ss, ax
    	mov sp, 0x9000 		; stack pointer 0x9000
    	mov ax, 0xB800
    	mov es, ax 			; memory address of printing on screen

    	sti

    call load_sectors 		; load rest sectors

    jmp sector_2

load_sectors:			 	; read and copy the rest sectors of disk

   	push es
    xor ax, ax
    mov es, ax									; es=0x0000
 	mov bx, sector_2 							; es:bx, Buffer Address Pointer
    mov ah,2 									; Read Sector Mode
    mov al,(sector_end - sector_2)/512 + 1  	; Sectors to Read Count
    mov ch,0 									; Cylinder Number=0
    mov cl,2 									; Sector Number=2
    mov dh,0 									; Head=0
    mov dl,0 									; Drive=0, A:drive
	int 0x13 									; BIOS interrupt
												; Services depend on ah value
    pop es
    ret

times   510-($-$$) db 0 		; $ : current address, $$ : start address of SECTION
								; $-$$ means the size of source
dw      0xAA55 					; signature bytes
								; End of Master Boot Record(1st Sector)
				
sector_2:						; Program Starts
	cli		
	lgdt	[gdt_ptr]			; Load GDT	
	
	mov eax, cr0
	or eax, 0x00000001
	mov cr0, eax			; Switch Real mode to Protected mode	

	jmp SYS_CODE_SEL:Protected_START	; jump Protected_START
											; Remove prefetch queue
Protected_START:
[bits 32]
	mov ax, SYS_DATA_SEL
	mov ds, ax
	mov ss, ax
	mov fs, ax
	mov gs, ax
	mov es, ax
	mov esp, 0xA000
	
	mov ax, Video_SEL
	mov es, ax
	
	mov eax, MSG_Protected_MODE_Test
	mov edi, 80*2*1+2*0
	mov bl, 0x02
	call printf_s

	;tss1 base addr
	mov eax, tss1
    mov word [gdt7+2], ax
    shr eax, 16
    mov byte [gdt7+4], al
    mov byte [gdt7+7], ah								
	
	;tss2 base addr
	mov eax, tss2
    mov word [gdt8+2], ax
    shr eax, 16
    mov byte [gdt8+4], al
    mov byte [gdt8+7], ah
	
	;fill the value of tss1
	mov word [tss1+76], TASK1_CODE_SEL	; CS
    mov word [tss1+84], SYS_DATA_SEL	; DS
    mov word [tss1+80], SYS_DATA_SEL	; SS
    mov word [tss1+72], Video_SEL		; ES
    mov dword [tss1+32], Task1			; EIP
    mov dword [tss1+56], 0xB000			; ESP
	
	;fill the value of tss2	
	mov word [tss2+76], TASK2_CODE_SEL	; CS
    mov word [tss2+84], SYS_DATA_SEL	; DS
    mov word [tss2+80], SYS_DATA_SEL	; SS
    mov word [tss2+72], Video_SEL		; ES
    mov dword [tss2+32], Task2			; EIP
    mov dword [tss2+56], 0xC000			; ESP		

;code your program----------------------------------------------------------------------------------------	
; Set offsets of Interrupt Descriptor 
	mov eax, ISR_00
	mov [IDT0], ax
	shr eax, 16
	mov [IDT0+6], ax
	
	mov eax, ISR_13
	mov [IDT13], ax
	shr eax, 16
	mov [IDT13+6], ax
	
	mov eax, ISR_80
	mov [IDT80], ax
	shr eax, 16
	mov [IDT80+6], ax
	
; Load IDT
	LIDT [IDT_ptr]
	
; Switch to Task 1

	jmp TSS1Selector:0

;----------------------------------------------------------------------------------------------------------
	
Task1:

	; Print "Entering Task1"
	
	mov eax, MSG_Task1
	mov edi, 80*2*2+2*0
	mov bl, 0x02
	call printf_s
	
	mov 	eax, 0x0
	mov 	ebx, 0x1
	mov 	ecx, 0x2
	mov 	edx, 0x3
	
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	
	call print_reg_1
	
				; this is ending point of program
				; when you complete the code, this line must be deactive 
	
	xor eax, eax
	xor ebx, ebx
	mov ax, 10
	mov bx, 0
	div bx
	
	
Task1_Return:	

	; Print "Task1 switched BACK from IRQ 00h"
	mov eax, MSG_Task1_Return
	mov edi, 80*2*3+2*0
	mov bl, 0x02
	call printf_s

	INT 48
	; Use IDT for switching Task2
	
Task2:

	; Print "Task2 switched from Task1"
	
	mov eax, MSG_Task2
	mov edi, 80*2*4+2*0
	mov bl, 0x02
	call printf_s
	
	mov 	eax, 0x4
	mov 	ebx, 0x5
	mov 	ecx, 0x6
	mov 	edx, 0x7
	
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	
	call print_reg_3
	
	jmp 48h:GP_Offset
	
Task2_Return:	
	; Print "Task2 switched BACK from IRQ 0Dh"
	mov eax, MSG_Task2_Return
	mov edi, 80*2*5+2*0
	mov bl, 0x02
	call printf_s
	
	
	mov 	eax, 0x4
	mov 	ebx, 0x5
	mov 	ecx, 0x6
	mov 	edx, 0x7
	
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx	
	
	INT 80
	; Call the User Defined Interrupt - ISR_80
	
Task2_Return2:	

	call print_reg_6

	; Print "Task2 switched BACK from IRQ 50h"
	mov eax, MSG_Task2_Return2
	mov edi, 80*2*6+2*0
	mov bl, 0x02
	call printf_s
	
	jmp $					; this is ending point of program
							; when return from IRQ, this line must be active to end program
	

GP_Offset:


	mov eax, MSG_GP_Offset
	mov edi, 80*2*6+2*0
	mov bl, 0x02
	call printf_s	
	
	jmp $
	
;-------------------Interrupt Service Routine(ISR)----------------	
ISR_00:

	; print "#DE : Divided by Zero"
	
	
	call print_reg_2
	
	mov eax, MSG_ISR_00
	mov edi, 80*2*9+2*0
	mov bl, 0x02
	call printf_s
	
	add esp, 12
	
	pop edx
	pop ecx
	pop ebx
	pop eax
	
	sub esp, 28
	
	mov dword [esp], Task1_Return	
	iret
	
	; Do not forget use push/pop (all and flags) for storing register values
	; return to Task1_Return
	

ISR_13: ; General Protection Fault


	call print_reg_4
	
	; print "#GP : General Protection Fault"		
	mov eax, MSG_ISR_13
	mov edi, 80*2*10+2*0
	mov bl, 0x02
	call printf_s
	
	add esp, 4
	add esp, 12
	
	pop edx
	pop ecx
	pop ebx
	pop eax
	
	sub esp, 28
	
	mov dword [esp], Task2_Return
	iret

	; Do not forget use push/pop (all and flags) for storing register values
	; return to Task2_Return	

ISR_80:	; User Defined ISR

	call print_reg_5

	; print "User Defined Interrupt"
	mov eax, MSG_ISR_80
	mov edi, 80*2*11+2*0
	mov bl, 0x02
	call printf_s
	
	; Do not forget use push/pop (all and flags) for storing register values
	add esp, 12
	
	pop edx
	pop ecx
	pop ebx
	pop eax
	
	sub esp, 28
	
	xor eax, eax
	xor ecx, ecx
	mov eax, 0x04
	mov ecx, eax
	mul cx
	dec ax

	mov dword [esp], Task2_Return2
	iret
	; return to Task2_Return2		
	
;-------------------------------------------------------------
MSG_Protected_MODE_Test: db'Protected Mode',0
MSG_Task1 : db 'Entering Task1', 0
MSG_Task1_Return : db 'Task1 switched BACK from IRQ 00h', 0
MSG_Task2 : db 'Task2 switched from Task1', 0
MSG_Task2_Return : db 'Task2 switched BACK from IRQ 0Dh', 0
MSG_Task2_Return2 : db 'Task2 switched BACK from IRQ 50h', 0
MSG_GP_Offset : db 'Offset that should not be executed', 0
MSG_ISR_00 : db '#DE : Divided by Zero', 0
MSG_ISR_13 : db '#GP : General Protection Fault', 0
MSG_ISR_80 : db 'User Defined Interrupt', 0
Name_Task1 : db '-Task 1-', 0
Name_Task2 : db '-Task 2-', 0
Name_Task2_Return2 : db '-Task 2-', 0
Name_ISR_00 : db '-ISR_00-', 0
Name_ISR_13 : db '-ISR_13-', 0
Name_ISR_80 : db '-ISR_80-', 0
temp: dd 0
;-------------------------------------------------------------
printf_s:
	mov cl, byte [ds:eax]
	mov byte [es: edi], cl
	inc edi
	mov byte [es: edi], bl
	inc edi

	inc eax								
	mov cl, byte [ds:eax]
	mov ch, 0
	cmp cl, ch							
	je printf_end						
	jmp printf_s	

printf_end:
	ret
	
printf_n:
	inc eax
	inc eax
	inc eax
	mov bh, 0x01
	jmp printf2
printf2:
	mov cl, byte [ds:eax]
	
	mov dl, cl
	shr dl, 4
	cmp dl, 0x09
	ja a1
	jmp a2
printf3:
	mov byte [es: edi], dl
	inc edi
	mov byte [es: edi], bl
	inc edi
	mov dl, cl
	and dl, 0x0f
	cmp dl, 0x09
	ja a3
	jmp a4
printf4:
	mov byte [es: edi], dl
	inc edi
	mov byte [es: edi], bl
	inc edi
	
	cmp bh, 0x04
	je printf_end1
	jmp a5

a1 :
	add dl, 0x37
	jmp printf3	
a2 :
	add dl, 0x30
	jmp printf3
a3 :
	add dl, 0x37
	jmp printf4
a4 :
	add dl, 0x30
	jmp printf4
a5 :
	add bh, 0x01
	dec eax
	jmp printf2
printf_end1:
	ret
	
print_name_1:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov eax, Name_Task1
	mov edi, 80*2*14+2*0					
	mov bl, 0x02
	call printf_s	
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret

print_reg_esp_1:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov eax, esp
	add eax, 0x18
	mov [temp], eax
	mov eax, temp
	mov edi, 80*2*15+2*0					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret	

print_reg_eax_1:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov [temp], eax
	mov eax, temp
	mov edi, 80*2*16+2*0					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret

print_reg_ebx_1:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov [temp], ebx
	mov eax, temp
	mov edi, 80*2*17+2*0					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret

print_reg_ecx_1:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov [temp], ecx
	mov eax, temp
	mov edi, 80*2*18+2*0					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret

print_reg_edx_1:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov [temp], edx
	mov eax, temp
	mov edi, 80*2*19+2*0					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret
	
print_reg_ds_1:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov [temp], ds
	mov eax, temp
	mov edi, 80*2*20+2*0					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret	

print_reg_cs_1:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov [temp], cs
	mov eax, temp
	mov edi, 80*2*21+2*0					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret	

print_reg_eflags_1:
	pushfd
	push eax
	push ebx
	push ecx
	push edx
	mov eax, [esp+16]
	mov [temp], eax
	mov eax, temp
	mov edi, 80*2*22+2*0					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	popfd
	ret	
	
print_reg_1:
	call print_name_1
	call print_reg_esp_1
	call print_reg_eax_1
	call print_reg_ebx_1
	call print_reg_ecx_1
	call print_reg_edx_1
	call print_reg_cs_1
	call print_reg_ds_1
	call print_reg_eflags_1
	ret

print_name_2:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov eax, Name_ISR_00
	mov edi, 80*2*14+2*10					
	mov bl, 0x02
	call printf_s	
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret

print_reg_esp_2:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov eax, esp
	add eax, 0x18
	mov [temp], eax
	mov eax, temp
	mov edi, 80*2*15+2*10					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret	

print_reg_eax_2:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov [temp], eax
	mov eax, temp
	mov edi, 80*2*16+2*10					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret

print_reg_ebx_2:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov [temp], ebx
	mov eax, temp
	mov edi, 80*2*17+2*10					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret

print_reg_ecx_2:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov [temp], ecx
	mov eax, temp
	mov edi, 80*2*18+2*10					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret

print_reg_edx_2:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov [temp], edx
	mov eax, temp
	mov edi, 80*2*19+2*10					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret
	
print_reg_ds_2:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov [temp], ds
	mov eax, temp
	mov edi, 80*2*20+2*10					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret	

print_reg_cs_2:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov [temp], cs
	mov eax, temp
	mov edi, 80*2*21+2*10					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret	

print_reg_eflags_2:
	pushfd
	push eax
	push ebx
	push ecx
	push edx
	mov eax, [esp+16]
	mov [temp], eax
	mov eax, temp
	mov edi, 80*2*22+2*10					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	popfd
	ret	
	
print_reg_2:
	call print_name_2
	call print_reg_esp_2
	call print_reg_eax_2
	call print_reg_ebx_2
	call print_reg_ecx_2
	call print_reg_edx_2
	call print_reg_cs_2
	call print_reg_ds_2
	call print_reg_eflags_2
	ret	

print_name_3:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov eax, Name_Task2
	mov edi, 80*2*14+2*20					
	mov bl, 0x02
	call printf_s	
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret

print_reg_esp_3:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov eax, esp
	add eax, 0x18
	mov [temp], eax
	mov eax, temp
	mov edi, 80*2*15+2*20					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret	

print_reg_eax_3:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov [temp], eax
	mov eax, temp
	mov edi, 80*2*16+2*20					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret

print_reg_ebx_3:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov [temp], ebx
	mov eax, temp
	mov edi, 80*2*17+2*20					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret

print_reg_ecx_3:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov [temp], ecx
	mov eax, temp
	mov edi, 80*2*18+2*20					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret

print_reg_edx_3:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov [temp], edx
	mov eax, temp
	mov edi, 80*2*19+2*20					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret
	
print_reg_ds_3:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov [temp], ds
	mov eax, temp
	mov edi, 80*2*20+2*20					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret	

print_reg_cs_3:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov [temp], cs
	mov eax, temp
	mov edi, 80*2*21+2*20					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret	

print_reg_eflags_3:
	pushfd
	push eax
	push ebx
	push ecx
	push edx
	mov eax, [esp+16]
	mov [temp], eax
	mov eax, temp
	mov edi, 80*2*22+2*20					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	popfd
	ret	

print_reg_3:
	call print_name_3
	call print_reg_esp_3
	call print_reg_eax_3
	call print_reg_ebx_3
	call print_reg_ecx_3
	call print_reg_edx_3
	call print_reg_cs_3
	call print_reg_ds_3
	call print_reg_eflags_3
	ret		
	
print_name_4:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov eax, Name_ISR_13
	mov edi, 80*2*14+2*30					
	mov bl, 0x02
	call printf_s	
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret

print_reg_esp_4:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov eax, esp
	add eax, 0x18
	mov [temp], eax
	mov eax, temp
	mov edi, 80*2*15+2*30					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret	

print_reg_eax_4:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov [temp], eax
	mov eax, temp
	mov edi, 80*2*16+2*30					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret

print_reg_ebx_4:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov [temp], ebx
	mov eax, temp
	mov edi, 80*2*17+2*30					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret

print_reg_ecx_4:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov [temp], ecx
	mov eax, temp
	mov edi, 80*2*18+2*30					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret

print_reg_edx_4:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov [temp], edx
	mov eax, temp
	mov edi, 80*2*19+2*30					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret
	
print_reg_ds_4:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov [temp], ds
	mov eax, temp
	mov edi, 80*2*20+2*30					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret	

print_reg_cs_4:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov [temp], cs
	mov eax, temp
	mov edi, 80*2*21+2*30					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret	

print_reg_eflags_4:
	pushfd
	push eax
	push ebx
	push ecx
	push edx
	mov eax, [esp+16]
	mov [temp], eax
	mov eax, temp
	mov edi, 80*2*22+2*30					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	popfd
	ret	

print_reg_4:
	call print_name_4
	call print_reg_esp_4
	call print_reg_eax_4
	call print_reg_ebx_4
	call print_reg_ecx_4
	call print_reg_edx_4
	call print_reg_cs_4
	call print_reg_ds_4
	call print_reg_eflags_4
	ret			
	
print_name_5:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov eax, Name_ISR_80
	mov edi, 80*2*14+2*40					
	mov bl, 0x02
	call printf_s	
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret

print_reg_esp_5:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov eax, esp
	add eax, 0x18
	mov [temp], eax
	mov eax, temp
	mov edi, 80*2*15+2*40					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret	

print_reg_eax_5:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov [temp], eax
	mov eax, temp
	mov edi, 80*2*16+2*40					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret

print_reg_ebx_5:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov [temp], ebx
	mov eax, temp
	mov edi, 80*2*17+2*40					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret

print_reg_ecx_5:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov [temp], ecx
	mov eax, temp
	mov edi, 80*2*18+2*40					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret

print_reg_edx_5:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov [temp], edx
	mov eax, temp
	mov edi, 80*2*19+2*40					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret
	
print_reg_ds_5:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov [temp], ds
	mov eax, temp
	mov edi, 80*2*20+2*40					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret	

print_reg_cs_5:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov [temp], cs
	mov eax, temp
	mov edi, 80*2*21+2*40					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret	

print_reg_eflags_5:
	pushfd
	push eax
	push ebx
	push ecx
	push edx
	mov eax, [esp+16]
	mov [temp], eax
	mov eax, temp
	mov edi, 80*2*22+2*40					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	popfd
	ret	

print_reg_5:
	call print_name_5
	call print_reg_esp_5
	call print_reg_eax_5
	call print_reg_ebx_5
	call print_reg_ecx_5
	call print_reg_edx_5
	call print_reg_cs_5
	call print_reg_ds_5
	call print_reg_eflags_5
	ret			

print_name_6:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov eax, Name_Task2_Return2
	mov edi, 80*2*14+2*50					
	mov bl, 0x02
	call printf_s	
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret

print_reg_esp_6:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov eax, esp
	add eax, 0x18
	mov [temp], eax
	mov eax, temp
	mov edi, 80*2*15+2*50					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret	

print_reg_eax_6:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov [temp], eax
	mov eax, temp
	mov edi, 80*2*16+2*50				
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret

print_reg_ebx_6:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov [temp], ebx
	mov eax, temp
	mov edi, 80*2*17+2*50					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret

print_reg_ecx_6:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov [temp], ecx
	mov eax, temp
	mov edi, 80*2*18+2*50					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret

print_reg_edx_6:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov [temp], edx
	mov eax, temp
	mov edi, 80*2*19+2*50					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret
	
print_reg_ds_6:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov [temp], ds
	mov eax, temp
	mov edi, 80*2*20+2*50					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret	

print_reg_cs_6:
	push 	eax    
	push	ebx
	push 	ecx
	push 	edx
	mov [temp], cs
	mov eax, temp
	mov edi, 80*2*21+2*50					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	ret	

print_reg_eflags_6:
	pushfd
	push eax
	push ebx
	push ecx
	push edx
	mov eax, [esp+16]
	mov [temp], eax
	mov eax, temp
	mov edi, 80*2*22+2*50					
	mov bl, 0x02
	call printf_n
	pop edx
	pop ecx
	pop ebx
	pop eax
	popfd
	ret	

print_reg_6:
	call print_name_6
	call print_reg_esp_6
	call print_reg_eax_6
	call print_reg_ebx_6
	call print_reg_ecx_6
	call print_reg_edx_6
	call print_reg_cs_6
	call print_reg_ds_6
	call print_reg_eflags_6
	ret							
	
;---------------------------tss----------------------------
tss1:
	dw 0, 0                     ; back link to previous task
	dd 0                        ; ESP0
	dw 0, 0                    	; SS0, not used here
	dd 0                        ; ESP1
	dw 0, 0                    	; SS1, not used here
	dd 0                        ; ESP2
	dw 0, 0                   	; SS2, not used here
	dd 0						; CR3
tss1_EIP:
	dd 0						; EIP
	dd 0						; EFLAGS
	dd 0, 0, 0, 0          		; EAX, ECX, EDX, EBX
tss1_ESP:
	dd 0						; ESP
	dd 0						; EBP
	dd 0						; ESI
	dd 0						; EDI
	dw 0, 0                    	; ES, not used here
	dw 0, 0                    	; CS, not used here
	dw 0, 0                    	; SS, not used here
	dw 0, 0                    	; DS, not used here
	dw 0, 0                    	; FS, not used here
	dw 0, 0                    	; GS, not used here
	dw 0, 0                    	; LDT, not used here
	dw 0, 0                    	; T bit for debugging

tss2:
	dw 0, 0                     ; back link to previous task
	dd 0                        ; ESP0
	dw 0, 0                    	; SS0, not used here
	dd 0                        ; ESP1
	dw 0, 0                    	; SS1, not used here
	dd 0                        ; ESP2
	dw 0, 0                   	; SS2, not used here
	dd 0						; CR3
tss2_EIP:
	dd 0						; EIP
	dd 0						; EFLAGS
	dd 0, 0, 0, 0          		; EAX, ECX, EDX, EBX
tss2_ESP:
	dd 0						; ESP
	dd 0						; EBP
	dd 0						; ESI
	dd 0						; EDI
	dw 0, 0                    	; ES, not used here
	dw 0, 0                    	; CS, not used here
	dw 0, 0                    	; SS, not used here
	dw 0, 0                    	; DS, not used here
	dw 0, 0                    	; FS, not used here
	dw 0, 0                    	; GS, not used here
	dw 0, 0                    	; LDT, not used here
	dw 0, 0                    	; T bit for debugging

;-------------------------Global Descriptor Table------------------------
;null descriptor. gdt_ptr could be put here to save a few
gdt:
	dw	0			; limit 15:0
	dw	0			; base 15:0
	db	0			; base 23:16
	db	0			; type
	db	0			; limit 19:16, flags
	db	0			; base 31:24
;Code Segment Descriptor
SYS_CODE_SEL equ	08h
gdt1:
	dw	0FFFFh		; limit 15:0
	dw	00000h		; base 15:0				
	db	0			; base 23:16
	db	9Ah			; present, ring 0, code, non-conforming, readable
	db	0cfh		; limit 19:16, flags
	db	0			; base 31:24
;Data Segment Descriptor
SYS_DATA_SEL equ	10h
gdt2:
	dw	0FFFFh		; limit 15:0
	dw	00000h		; base 23:16			
	db	0			; base 23:16
	db	92h			; present, ring 0, data, expand-up, writable
	db	0cfh		; limit 19:16, flags
	db	0			; base 31:24
;Video Segment Descriptor
Video_SEL	equ	18h				
gdt3:
	dw	0FFFFh		; limit 15:0
	dw	08000h		; base 23:16			
	db	0Bh			; base 23:16
	db	92h			; present, ring 0, data, expand-up, writable
	db	40h			; limit 19:16, flags
	db	00h			; base 31:24
;Code Segment Descriptor
SYS_EXT_SEL    equ	20h
gdt4:
	dw	0FFFFh	; limit 15:0
	dw	00000h	; base 15:0				
	db	0		; base 23:16
	db	9Ah		; present, ring 0, code, non-conforming, readable
	db	0cfh	; limit 19:16, flags
	db	0		; base 31:24	
;Code Segment Descriptor
TASK1_CODE_SEL equ	28h
gdt5:
	dw	0FFFFh		; limit 15:0
	dw	00000h		; base 15:0				
	db	0			; base 23:16
	db	9Ah			; present, ring 0, code, non-conforming, readable
	db	0cfh		; limit 19:16, flags
	db	0			; base 31:24
;Code Segment Descriptor
TASK2_CODE_SEL equ	30h
gdt6:
	dw	0FFFFh		; limit 15:0
	dw	00000h		; base 15:0				
	db	0			; base 23:16
	db	9Ah			; present, ring 0, code, non-conforming, readable
	db	0cfh		; limit 19:16, flags
	db	0			; base 31:24	
	
; TSS Descriptor
TSS1Selector	equ		38h					
gdt7:
	dw	068h	; Segment Limit 15:0
	dw	0000h	; Base Address 15:0
	db	00h		; Base Address 23:16
	db	89h		; present, ring 0, system, 32-bit TSS Type	
	db	00h		; limit 19:16, flags
	db	00h		; Base Address 31:24
; TSS Descriptor
TSS2Selector	equ		40h					
gdt8:
	dw	068h	; Segment Limit 15:0
	dw	0000h	; Base Address 15:0
	db	00h		; Base Address 23:16
	db	89h		; present, ring 0, system, 32-bit TSS Type													
	db	00h		; limit 19:16, flags
	db	00h		; Base Address 31:24

gdt_end:

gdt_ptr:
	dw	gdt_end - gdt - 1	; GDT limit
	dd	gdt		; linear addr of GDT (set above)

;----------------------Interrupt Descriptor Table------------------------	
;-------------------------write your code here---------------------------
; Make Interrupt Descriptor Table	
;																        ;	
IDT0:
	dw 0
	dw SYS_EXT_SEL
	db 0
	db 8Eh
	dw 0
	
IDT1:
    dq 0
IDT2:
    dq 0
IDT3:
    dq 0
IDT4:
    dq 0
IDT5:
    dq 0
IDT6:
    dq 0
IDT7:
    dq 0
IDT8:
    dq 0
IDT9:
    dq 0
IDT10:
    dq 0
IDT11:
    dq 0
IDT12:
    dq 0
IDT13:
	dw 0
	dw SYS_EXT_SEL
	db 0
	db 8Eh
	dw 0
	
IDT14:
    dq 0
IDT15:
    dq 0
IDT16:
    dq 0
IDT17:
    dq 0
IDT18:
    dq 0
IDT19:
    dq 0
IDT20:
    dq 0
IDT21:
    dq 0
IDT22:
    dq 0
IDT23:
    dq 0
IDT24:
    dq 0
IDT25:
    dq 0
IDT26:
    dq 0
IDT27:
    dq 0
IDT28:
    dq 0
IDT29:
    dq 0
IDT30:
    dq 0
IDT31:
    dq 0
IDT32:
    dq 0
IDT33:
    dq 0
IDT34:
    dq 0
IDT35:
    dq 0
IDT36:
    dq 0
IDT37:
    dq 0
IDT38:
    dq 0
IDT39:
    dq 0
IDT40:
    dq 0
IDT41:
    dq 0
IDT42:
    dq 0
IDT43:
    dq 0
IDT44:
    dq 0
IDT45:
    dq 0
IDT46:
    dq 0
IDT47:
    dq 0
IDT48:
    dw 0
	dw TSS2Selector
	db 0
	db 85h
	dw 0
IDT49:
    dq 0
IDT50:
    dq 0
IDT51:
    dq 0
IDT52:
    dq 0
IDT53:
    dq 0
IDT54:
    dq 0
IDT55:
    dq 0
IDT56:
    dq 0
IDT57:
    dq 0
IDT58:
    dq 0
IDT59:
    dq 0
IDT60:
    dq 0
IDT61:
    dq 0
IDT62:
    dq 0
IDT63:
    dq 0
IDT64:
    dq 0
IDT65:
    dq 0
IDT66:
    dq 0
IDT67:
    dq 0
IDT68:
    dq 0
IDT69:
    dq 0
IDT70:
    dq 0
IDT71:
    dq 0
IDT72:
    dq 0
IDT73:
    dq 0
IDT74:
    dq 0
IDT75:
    dq 0
IDT76:
    dq 0
IDT77:
    dq 0
IDT78:
    dq 0
IDT79:
    dq 0
IDT80:
	dw 0
	dw SYS_EXT_SEL
	db 0
	db 8Eh
	dw 0

IDT_END:

IDT_ptr:
	dw	IDT_END - IDT0 - 1	; IDT limit
	dd	IDT0		; linear addr of IDT (set above)
;																        ;	
;																        ;	
;																        ;	
;																        ;	
;																        ;	
;------------------------------------------------------------------------
sector_end:

