; Disassembler for Intel 8086 processor instruction set
;
; Created by Martynas Ðapalas in 2016-11 for learning purposes as an 
; extra task at the university.
;
; The program works only with .com files
;
; How does it work? 
; One byte is taken from the input buffer. Looking at
; the pointers to functions with an offset of that byte, the program jumps
; to a specific function where further actions begin. These functions 
; disassemble a specific group of commands which have the same or similar
; format. Inside these functions it is estimated how many more bytes to read,
; the parameters are parsed and finally a name and arguments are printed
;
; To-do: REP, REPNZ prefixes
;
.model small
.stack 200h

max_file_name_size  = 64
max_file_size       = 64 ; buffer size

; Constants for output buffer
machinecode_begin   = 9
cmdname_begin       = 24
arguments_begin     = 32

.data
    HelpMsg db  "DISASEMBLERIS", 10, 13
            db  "Kurejas: Martynas Sapalas, programu sistemu 1 kursas, 2 grupe.", 10, 13
            db  "Programa nuskaito masinini koda is .com formato failo ir isveda", 10, 13
            db  "i rezultatu faila visas disasembliuotas komandas.", 10, 13
            db  "Teisingas programos iskvietimas: disass.asm [ivesties_failas] [rezultato failas]$"
    FailedOpeningMsg    db  "Ivyko klaida atidarant duomenu faila.$"
    NoDataMsg           db  "Klaida: is failo nieko nebuvo nuskaityta.$"
    FailedWriteMsg      db  "Ivyko klaida rasant duomenis i rezultatu faila.$"
    FileIn              db  max_file_name_size dup(0)       ; input file name
    FileOut             db  max_file_name_size dup(0)       ; output file name
    FileInHan           dw  0                               ; input file handler
    FileOutHan          dw  0                               ; output file handler
    BytesRead           db  0                               ; how many bytes already read
    InputBuffer         db  0 
                        db  max_file_size dup (0)           ; input buffer - the machine code
    OutputBuffer        db  0, 64 dup(32)                   ; output buffer, only for one command
    CmdLine             dw  100h                            ; the line of the command
    FirstByteAddress    dw  ?                               ; first currently proceesed command byte
    ;--------------------------------------   
    ; Command parameters from machine code
    p_d     db  ?           ; destination (d) bit
    p_w     db  ?           ; width (w) bit
    p_s     db  0           ; s bit
    p_mod   db  ?           ; mod (2 bits)
    p_reg   db  ?           ; register (reg) (3 bits)
    p_rm    db  ?           ; r/m (3 bits)
    p_off_l db  ?           ; low-order byte of offset
    p_off_h db  ?           ; high-order byte of offset 
    p_sr    db  -1           ; segment register
    p_bol   db  ?           ; direct value low-order byte
    p_boh   db  ?           ; direct value high-order byte  
    ; Flags
    f_num   db  0           ; is there a constant number in the command?
    ; Pointer name
    d_byte  db  "byte ptr ", 0
    d_word  db  "word ptr ", 0
    ptr_names   dw offset d_byte
                dw offset d_word
    HexDigits   db  '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'
    ;--------------------------------------
    ; Command OpCodes:
    c_AAA   db  "aaa", 0
    c_AAD   db  "aad", 0
    c_AAM   db  "aam", 0
    c_AAS   db  "aas", 0
    c_ADD   db  "add", 0
    c_ADC   db  "adc", 0
    c_AND   db  "and", 0
    c_CALL  db  "call", 0
    c_CBW   db  "cbw", 0
    c_CBC   db  "cbc", 0
    c_CLC   db  "clc", 0
    c_CLD   db  "cld", 0
    c_CLI   db  "cli", 0
    c_CMC   db  "cmc", 0
    c_CMP   db  "cmp", 0
    c_CMPS  db  "cmps", 0
    c_CWD   db  "cwd", 0
    c_DAA   db  "daa", 0
    c_DAS   db  "das", 0
    c_DEC   db  "dec", 0
    c_DIV   db  "div", 0
    c_HLT   db  "hlt", 0
    c_IDIV  db  "idiv", 0
    c_IMUL  db  "imul", 0
    c_IN    db  "in", 0
    c_INC   db  "inc", 0
    c_INT   db  "int", 0
    c_INT3  db  "int 3", 0
    c_INTO  db  "into", 0
    c_IRET  db  "iret", 0
    c_JA    db  "ja", 0
    c_JB    db  "jb", 0
    c_JBE   db  "jbe", 0
    c_JCXZ  db  "jcxz", 0
    c_JE    db  "je", 0
    c_JG    db  "jg", 0
    c_JGE   db  "jge", 0
    c_JL    db  "jl", 0
    c_JLE   db  "jle", 0
    c_JMP   db  "jmp", 0
    c_JNB   db  "jnb", 0
    c_JNE   db  "jne", 0
    c_JNO   db  "jno", 0
    c_JNP   db  "jnp", 0
    c_JNS   db  "jns", 0
    c_JO    db  "jo", 0
    c_JP    db  "jp", 0
    c_JS    db  "js", 0
    c_LAHF  db  "lahf", 0
    c_LDS   db  "lds", 0
    c_LEA   db  "lea", 0
    c_LES   db  "les", 0
    c_LOCK  db  "lock", 0
    c_LODS  db  "lods", 0
    c_LOOP  db  "loop", 0
    c_LOOPE db  "loope", 0
    c_LOOPN db  "loopne", 0
    c_MOV   db  "mov", 0
    c_MOVS  db  "movs", 0
    c_MUL   db  "mul", 0
    c_NEG   db  "neg", 0
    c_NOT   db  "not", 0
    c_NOP   db  "nop", 0
    c_OR    db  "or", 0
    c_OUT   db  "out", 0
    c_PUSH  db  "push", 0
    c_PUSHF db  "pushf", 0
    c_POP   db  "pop", 0
    c_POPF  db  "popf", 0
    c_REP   db  "rep", 0
    c_REPNZ db  "repnz", 0
    c_RET   db  "ret", 0
    c_RETF  db  "retf", 0
    c_RCL   db  "rcl", 0
    c_RCR   db  "rcr", 0
    c_ROL   db  "rol", 0
    c_ROR   db  "ror", 0
    c_SAHF  db  "sahf", 0
    c_SAR   db  "sar", 0
    c_SBB   db  "sbb", 0
    c_SCAS  db  "scas", 0
    c_SHL   db  "shl", 0
    c_SHR   db  "shr", 0
    c_STC   db  "stc", 0
    c_STD   db  "std", 0
    c_STI   db  "sti", 0
    c_STOS  db  "stos", 0
    c_SUB   db  "sub", 0
    c_TEST  db  "test", 0
    c_WAIT  db  "wait", 0
    c_XCHG  db  "xchg", 0
    c_XLAT  db  "xlat", 0
    c_XOR   db  "xor", 0
    c_UNKNOWN   db  "UNKNOWN", 0
    ; Conditional jumps' pointers
    c_CONDJMP   dw offset c_JO
                dw offset c_JNO
                dw offset c_JB 
                dw offset c_JNB
                dw offset c_JE 
                dw offset c_JNE 
                dw offset c_JBE
                dw offset c_JA 
                dw offset c_JS 
                dw offset c_JNS 
                dw offset c_JP 
                dw offset c_JNP
                dw offset c_JL 
                dw offset c_JGE 
                dw offset c_JLE 
                dw offset c_JG
    ; Registers
    r_AL    db  "al", 0
    r_CL    db  "cl", 0
    r_DL    db  "dl", 0
    r_BL    db  "bl", 0
    r_AH    db  "ah", 0
    r_CH    db  "ch", 0
    r_DH    db  "dh", 0
    r_BH    db  "bh", 0
    r_AX    db  "ax", 0
    r_CX    db  "cx", 0
    r_DX    db  "dx", 0
    r_BX    db  "bx", 0
    r_SP    db  "sp", 0
    r_BP    db  "bp", 0
    r_SI    db  "si", 0
    r_DI    db  "di", 0
    ; Pointers to registers' names
    ptr_REG dw offset r_AL
            dw offset r_CL
            dw offset r_DL
            dw offset r_BL
            dw offset r_AH
            dw offset r_CH 
            dw offset r_DH
            dw offset r_BH
            dw offset r_AX
            dw offset r_CX
            dw offset r_DX 
            dw offset r_BX 
            dw offset r_SP
            dw offset r_BP
            dw offset r_SI
            dw offset r_DI
    ; Segment registers
    r_ES    db  "es", 0
    r_CS    db  "cs", 0
    r_SS    db  "ss", 0
    r_DS    db  "ds", 0
    ;Pointers to segment registers' names
    ptr_SREG dw offset r_ES
             dw offset r_CS
             dw offset r_SS
             dw offset r_DS
    ; r/m all cases of adressing
    a_000   db  "bx+si", 0
    a_001   db  "bx+di", 0
    a_010   db  "bp+si", 0
    a_011   db  "bp+di", 0
    a_100   db  "si", 0
    a_101   db  "di", 0
    a_110   db  "bp", 0
    a_111   db  "bx", 0
    ptr_RM  dw offset a_000
            dw offset a_001
            dw offset a_010
            dw offset a_011
            dw offset a_100
            dw offset a_101
            dw offset a_110
            dw offset a_111
    ; Pointers to functions (always add assigning of the adress!)
    Ptr_Cmd_Opc_D_W_Mod_Reg_Rm_Offset       dw ?
    Ptr_Cmd_Opc_Bop                         dw ?
    Ptr_Cmd_Opc_Sr_Opc                      dw ?
    Ptr_Cmd_Opc_Offset                      dw ?
    Ptr_Cmd_Opc_S_W_Mod_Opc_Rm_Offset_Bop   dw ?
    Ptr_Cmd_Opc_Reg                         dw ?
    Ptr_Cmd_Opc_W_Mod_Opc_Rm_Offset         dw ?
    Ptr_Cmd_Opc_W_Rm                        dw ?
    Ptr_Cmd_Opc_Adr_Seg                     dw ?
    Ptr_Cmd_Opc_Number                      dw ?
    Ptr_Cmd_Opc                             dw ?
    Ptr_Cmd_Opc_Str                         dw ?
    Ptr_Cmd_Opc_Bopl_Boph                   dw ?
    Ptr_CmdUnknownCmd                       dw ?
    ; Pointers to function pointers, working with certain groups
    fptrptr dw 4 dup(offset Ptr_Cmd_Opc_D_W_Mod_Reg_Rm_Offset)      ; 00-03: ADD reg, r/m
            dw 2 dup(offset Ptr_Cmd_Opc_Bop)                        ; 04-05: ADD ax, value
            dw 2 dup(offset Ptr_Cmd_Opc_Sr_Opc)                     ; 06-07: PUSH, POP with sr = 00
            dw 4 dup(offset Ptr_Cmd_Opc_D_W_Mod_Reg_Rm_Offset)      ; 08-0B: OR reg, r/m
            dw 2 dup(offset Ptr_Cmd_Opc_Bop)                        ; 0C-0D: OR ax, value
            dw 2 dup(offset Ptr_Cmd_Opc_Sr_Opc)                     ; 0E-0F: PUSH, POP with sr = 01
            dw 4 dup(offset Ptr_Cmd_Opc_D_W_Mod_Reg_Rm_Offset)      ; 10-13: ADC reg, r/m
            dw 2 dup(offset Ptr_Cmd_Opc_Bop)                        ; 14-15: ADC ax, value
            dw 2 dup(offset Ptr_Cmd_Opc_Sr_Opc)                     ; 16-17: PUSH, POP with sr = 10
            dw 4 dup(offset Ptr_Cmd_Opc_D_W_Mod_Reg_Rm_Offset)      ; 18-1B: SBB reg, r/m
            dw 2 dup(offset Ptr_Cmd_Opc_Bop)                        ; 1C-1D: SBB ax, value
            dw 2 dup(offset Ptr_Cmd_Opc_Sr_Opc)                     ; 1E-1F: PUSH, POP with sr = 11
            dw 4 dup(offset Ptr_Cmd_Opc_D_W_Mod_Reg_Rm_Offset)      ; 20-23: AND reg, r/m
            dw 2 dup(offset Ptr_Cmd_Opc_Bop)                        ; 24-25: AND ax, value
            dw 1 dup(offset Ptr_Cmd_Opc_Sr_Opc)                     ; 26:    "es:" prefix
            dw 1 dup(offset Ptr_Cmd_Opc)                            ; 27:    DAA
            dw 4 dup(offset Ptr_Cmd_Opc_D_W_Mod_Reg_Rm_Offset)      ; 28-2B: SUB reg, r/m
            dw 2 dup(offset Ptr_Cmd_Opc_Bop)                        ; 2C-2D: SUB ax, value
            dw 1 dup(offset Ptr_Cmd_Opc_Sr_Opc)                     ; 2E:    "cs:" prefix
            dw 1 dup(offset Ptr_Cmd_Opc)                            ; 2F:    DAS
            dw 4 dup(offset Ptr_Cmd_Opc_D_W_Mod_Reg_Rm_Offset)      ; 30-33: XOR reg, r/m
            dw 2 dup(offset Ptr_Cmd_Opc_Bop)                        ; 34-35: XOR ax, value
            dw 1 dup(offset Ptr_Cmd_Opc_Sr_Opc)                     ; 36:    "ss:" prefix
            dw 1 dup(offset Ptr_Cmd_Opc)                            ; 37:    AAA
            dw 4 dup(offset Ptr_Cmd_Opc_D_W_Mod_Reg_Rm_Offset)      ; 38-3B: CMP reg, r/m
            dw 2 dup(offset Ptr_Cmd_Opc_Bop)                        ; 3C-3D: CMP ax, value
            dw 1 dup(offset Ptr_Cmd_Opc_Sr_Opc)                     ; 3E:    "ds:" prefix
            dw 1 dup(offset Ptr_Cmd_Opc)                            ; 3F:    AAS
            dw 32 dup(offset Ptr_Cmd_Opc_Reg)                       ; 40-5F: INC, DEC, PUSH, POP with reg
            dw 16 dup(offset Ptr_CmdUnknownCmd)                     ; 60-6F: not used
            dw 16 dup(offset Ptr_Cmd_Opc_Offset)                    ; 70-7F: conditional jumps
            dw 4 dup(offset Ptr_Cmd_Opc_S_W_Mod_Opc_Rm_Offset_Bop)  ; 80-83: ADD, SUB, CMP, OR, ADC, SBB, AND, XOR r/m, value
            dw 11 dup(offset Ptr_Cmd_Opc_D_W_Mod_Reg_Rm_Offset)     ; 84-8E: TEST, XCHG, MOV, LEA reg(sr), r/m
            dw 1 dup(offset Ptr_Cmd_Opc_W_Mod_Opc_Rm_Offset)        ; 8F:    POP r/m   
            dw 1 dup(offset Ptr_Cmd_Opc)                            ; 90:    NOP
            dw 7 dup(offset Ptr_Cmd_Opc_Reg)                        ; 91-97: XCHG reg
            dw 2 dup(offset Ptr_Cmd_Opc)                            ; 98-99: CBW, CWD
            dw 1 dup(offset Ptr_Cmd_Opc_Adr_Seg)                    ; 9A:    CALL direct far 
            dw 5 dup(offset Ptr_Cmd_Opc)                            ; 9B-9F: WAIT, PUSHF, POPF, SAHF, LAHF
            dw 4 dup(offset Ptr_Cmd_Opc_W_Rm)                       ; A0-A3: MOV ax, r/m
            dw 4 dup(offset Ptr_Cmd_Opc_Str)                        ; A4-A7: MOVS, CMPS
            dw 2 dup(offset Ptr_Cmd_Opc_Bop)                        ; A8-A9: TEST ax, value
            dw 6 dup(offset Ptr_Cmd_Opc_Str)                        ; AA-AF: STOS, LODS, SCAS
            dw 16 dup(offset Ptr_Cmd_Opc_Bop)                       ; B0-BF: MOV reg, value  
            dw 2 dup(offset Ptr_CmdUnknownCmd)                      ; C0-C1: not used
            dw 1 dup(offset Ptr_Cmd_Opc_Bopl_Boph)                  ; C2:    RET value  
            dw 1 dup(offset Ptr_Cmd_Opc)                            ; C3:    RET      
            dw 2 dup(offset Ptr_Cmd_Opc_D_W_Mod_Reg_Rm_Offset)      ; C4-C5: LES, LDS
            dw 2 dup(offset Ptr_Cmd_Opc_S_W_Mod_Opc_Rm_Offset_Bop)  ; C6-C7: MOV r/m, value
            dw 2 dup(offset Ptr_CmdUnknownCmd)                      ; C8-C9: not used
            dw 1 dup(offset Ptr_Cmd_Opc_Bop)                        ; CA:    RETF value
            dw 2 dup(offset Ptr_Cmd_Opc)                            ; CB-CC: RETF, INT 3
            dw 1 dup(offset Ptr_Cmd_Opc_Number)                     ; CD:    INT number  
            dw 2 dup(offset Ptr_Cmd_Opc)                            ; CE-CF: INTO, IRET
            dw 4 dup(offset Ptr_Cmd_Opc_W_Mod_Opc_Rm_Offset)        ; D0-D3: ROL, ROR, RCL, RCR, SHL, SHR, SAR
            dw 2 dup(offset Ptr_Cmd_Opc)                            ; D4-D5: AAM, AAD
            dw 1 dup(offset Ptr_CmdUnknownCmd)                      ; D6:    not used
            dw 1 dup(offset Ptr_Cmd_Opc)                            ; D7:    XLAT
            dw 8 dup(offset Ptr_CmdUnknownCmd)                      ; D8-DF: not used
            dw 4 dup(offset Ptr_Cmd_Opc_Offset)                     ; E0-E3: LOOPNE, LOOPE, LOOP and JCXZ
            dw 4 dup(offset Ptr_Cmd_Opc_Number)                     ; E4-E7: IN, OUT number
            dw 2 dup(offset Ptr_Cmd_Opc_Offset)                     ; E8-E9: CALL and JMP direct near 
            dw 1 dup(offset Ptr_Cmd_Opc_Adr_Seg)                    ; EA:    JMP far direct 
            dw 1 dup(offset Ptr_Cmd_Opc_Offset)                     ; EB:    JMP close
            dw 4 dup(offset Ptr_Cmd_Opc)                            ; EC-EF: IN, OUT with dx
            dw 1 dup(offset Ptr_Cmd_Opc)                            ; F0:    LOCK
            dw 1 dup(offset Ptr_CmdUnknownCmd)                      ; F1:    not used
            dw 4 dup(offset Ptr_Cmd_Opc)                            ; F2-F5: REPNZ, REP, HLT, CMC
            dw 2 dup(offset Ptr_Cmd_Opc_W_Mod_Opc_Rm_Offset)        ; F6-F7: (TEST), NOT, NEG, IMUL, IDIVMUL or DIV r/m
            dw 6 dup(offset Ptr_Cmd_Opc)                            ; F8-FD: CLC, STC, CLI, STI, CLD, STD
            dw 2 dup(offset Ptr_Cmd_Opc_W_Mod_Opc_Rm_Offset)        ; FE-FF: INC, DEC, CALL
.code
;=====================================================================
; PROCEDURES
;---------------------------------------------------------------------
; Parses input and output files' names entered in standard input
; to memory in segment ds
; IN:   bx - file name beginning adress
;       si - offset from es:0082h
GetFileNames    PROC
    mov di, 0                   ; destination file
@GetLetter:
    mov cl, es:[si+82h]
    cmp cl, ' '
    je @EndGetting
    cmp cl, 13                  ; 13d - carriage return, end of command line input
    je @EndGetting
    mov [bx+di], cl
    inc si
    inc di
    cmp di, max_file_name_size  ; maksimalus ilgis - 64 simboliai
    jl @GetLetter
@EndGetting:
    inc si
    ret
ENDP GetFileNames
;---------------------------------------------------------------------
; Opens input file
; IN    bx - file handler
;       dx - file name offset
;       al - opening mode
; OUT   [bx] - file handler
OpenFile PROC
    mov ah, 3Dh
    int 21h 
    jc @EndOpening
    mov [bx], ax
@EndOpening:
    ret
ENDP OpenFile
;---------------------------------------------------------------------
; Move pointer in input file
; IN    dx - number to move from current position (low-order word)
MoveFilePointer PROC
    mov ah, 42h
    mov al, 1
    mov bx, FileInHan
    mov cx, 0FFFFh                    ; offset high-order word
    int 21h
    ret
ENDP MoveFilePointer
;---------------------------------------------------------------------
; Reads input file
ReadFile PROC
    ; set read bytes number to 0
    mov BytesRead, 0
    ; proceed to reading
    mov ah, 3Fh
    mov bx, FileInHan
    mov cx, max_file_size
    mov dx, offset InputBuffer+1
    int 21h
    jc @EndReading
    mov bx, offset InputBuffer
    mov byte ptr [bx], al
@EndReading:
    ret
ENDP ReadFile
;---------------------------------------------------------------------
; Return byte in hex format to output buffer
; IN -  di - the destination index in output
;       al -  passed byte
ByteToHex PROC
    push ax
    push bx
    push cx
    push dx
    push bp
    mov bp, sp
    ; move first digit
    mov bh, 0
    mov bl, al
    and bl, 11110000b
    shr bl, 4
    add bx, offset HexDigits
    mov dl, byte ptr [bx]   
    mov bx, offset OutputBuffer
    mov [bx+di], dl
    inc di
    inc OutputBuffer
    ; move second digit  
    mov bh, 0
    mov bl, al  
    and bl, 00001111b
    add bx, offset HexDigits
    mov dl, byte ptr [bx] 
    mov bx, offset OutputBuffer
    mov [bx+di], dl
    inc di
    inc OutputBuffer
    ;---- 
    pop bp
    pop dx
    pop cx
    pop bx
    pop ax
    ret
ENDP ByteToHex
;---------------------------------------------------------------------
; Moves byte from input buffer to output buffer
; OUT   al - read byte
ReadByte PROC
    mov al, byte ptr [si + offset InputBuffer]  ; parse first byte
    mov ah, 0
    inc si
    call ByteToHex
    inc CmdLine
    inc BytesRead
    ret
ENDP ReadByte
;---------------------------------------------------------------------
; Writes line to the output file
; Line format:
; [offset] [machine_code] [assembler_command]
WriteLineToFile PROC
    mov ah, 40h
    mov bx, FileOutHan
    mov cl, OutputBuffer  
    mov ch, 0
    mov dx, offset OutputBuffer+1
    int 21h
    jc @EndWriting
    mov cx, 0
@EndWriting:
    ret
ENDP WriteLineToFile 
;---------------------------------------------------------------------
; Closes files
CloseFiles PROC
    mov ah, 3Eh
    mov bx, offset FileInHan
    int 21h    
    mov ah, 3Eh
    mov bx, offset FileOutHan
    int 21h  
    ret
ENDP CloseFiles
;---------------------------------------------------------------------
; Write line number to the output file
WriteLineNumber PROC
    mov al, byte ptr offset CmdLine+1
    mov ah, 0
    call ByteToHex
    mov al, byte ptr offset CmdLine
    mov ah, 0
    call ByteToHex
    ; add new line at the end of output buffer
    mov al, ':'
    call WriteChar
@WriteLineNumber_Spaces:             ; write spaces after line number
    mov al, ' '
    call WriteChar
    cmp di, machinecode_begin
    jbe @WriteLineNumber_Spaces 
    ret
ENDP WriteLineNumber
;---------------------------------------------------------------------
; Move file pointer and read next 64 bytes
MovePtr PROC
    mov dh, 0FFh
    mov dl, BytesRead
    sub dl, InputBuffer
    call MoveFilePointer
    ; Read input file once again
    call ReadFile
    mov bx, offset InputBuffer
    mov si, 1
    ret
ENDP MovePtr
;---------------------------------------------------------------------
; Write command name to output buffer
; IN:   ax - beginning adress of the name
WriteCmdName PROC
    push si
    mov si, ax
    ; write spaces before
@WriteCmdName_SpacesBefore:             ; write spaces after line number
    mov al, ' '
    call WriteChar
    cmp di, cmdname_begin
    jbe @WriteCmdName_SpacesBefore 
    ; write name
    mov ax, si
    call WriteString
    ; write spaces after
@WriteCmdName_SpacesAfter:             ; write spaces after line number
    mov al, ' '
    call WriteChar
    cmp di, arguments_begin
    jbe @WriteCmdName_SpacesAfter    
    pop si
    ret
ENDP WriteCmdName
;---------------------------------------------------------------------
; Prints out two command arguments by looking at d, w, mod, reg, rm, offsets
WriteRegRmArguments PROC
    cmp p_d, 1
    je @WriteArgumentsReversed
    call WriteRm
    call WriteSeparator
    call WriteReg
    jmp @WriteArgumentsEnd
@WriteArgumentsReversed:
    call WriteReg
    call WriteSeparator
    call WriteRm
@WriteArgumentsEnd:
    ret
WriteRegRmArguments ENDP
;---------------------------------------------------------------------
; Prints out the register
WriteReg PROC
    push ax
    push bx
    mov bh, 0
    mov bl, p_w
    shl bl, 3
    add bl, p_reg
    add bl, bl              ; 2 * bl
    add bx, offset ptr_REG
    mov ax, [bx]
    call WriteString
    pop bx
    pop ax
    ret
ENDP WriteReg
;---------------------------------------------------------------------
; Prints out the separator ", "
WriteSeparator PROC
    push ax
    mov al, ','
    call WriteChar
    mov al, ' '
    call WriteChar
    pop ax
    ret
ENDP WriteSeparator
;---------------------------------------------------------------------
; Prints out the r/m field
WriteRm PROC
    push ax
    push bx
    ;-----------
    cmp p_mod, 11b
    jl @RmNotReg
    ; Case when r/m is a register.
    mov bh, 0
    mov bl, p_w
    shl bl, 3
    add bl, p_rm
    add bl, bl              ; 2 * bl
    add bx, offset ptr_REG
    mov ax, [bx]
    call WriteString
    jmp WriteRmEnd
@RmNotReg:
    cmp f_num, 0            ; check for constants in command to add "xxx ptr " if needed
    je @RmNoConstants
    mov bl, f_num
    mov bh, 0
    add bx, bx
    add bx, offset ptr_names
    mov ax, [bx-2]
    call WriteString
    ;-----------------------------
@RmNoConstants:
    ; check for segment changing prefix
    cmp byte ptr p_sr, -1
    je @RmPrintBegin
    call WriteSr
    mov al, ':'
    call WriteChar
@RmPrintBegin:
    mov al, '['
    call WriteChar        ; print '['
    ;-----------------------------
    ; check the special case, when mod = 00 and r/m = 110 (direct adressing)
    cmp p_mod, 00b
    jg @RmPrintReg
    cmp p_rm, 110b
    je @RmWithOffset
@RmPrintReg:
    mov bl, p_rm
    mov bh, 0
    add bx, bx
    add bx, offset ptr_RM
    mov ax, [bx]
    call WriteString          ; prints all registers before offset
    cmp p_mod, 00b
    je @RmEndAdress
    mov al, '+'
    call WriteChar        ; prints '+'
@RmWithOffset:
    mov bx, FirstByteAddress
    cmp p_mod, 01b
    je @RmOffsetByteCheckZero
    cmp byte ptr p_off_h, 0A0h
    jb @RwOffsetTwoBytesNoZero
    mov al, '0'             ; '0' before high-order byte
    call WriteChar
@RwOffsetTwoBytesNoZero:
    mov al, p_off_h
    call ByteToHex          ; print high-order byte
    jmp @RmOffsetByte
@RmOffsetByteCheckZero:
    cmp byte ptr p_off_l, 0A0h
    jb @RmOffsetByte
    mov al, '0'             ; '0' before low-order byte (if mod = 01)
    call WriteChar
@RmOffsetByte:    
    mov al, p_off_l
    call ByteToHex          ; print low-order byte
    mov al, 'h'
    call WriteChar
@RmEndAdress:
    ;-----------------------------
    mov al, ']'
    call WriteChar          ; print ']'
WriteRmEnd:
    pop bx
    pop ax
    ret
ENDP WriteRm
;---------------------------------------------------------------------
; Write direct value (number) out
; IN    bx - offset of number
WriteDirectValue PROC
    push ax
    cmp p_w, 0
    je @WriteDirectValue_OnlyOneZeroCheck
    cmp p_s, 1
    jne @WriteDirectValue_PrintHigher   
    cmp byte ptr p_bol, 80h             ; sw = 01
    jb @WriteDirectValue_ExtendZero
    mov byte ptr p_boh, 0FFh
    jmp @WriteDirectValue_PrintHigher
@WriteDirectValue_ExtendZero:
    mov byte ptr p_boh, 0
@WriteDirectValue_PrintHigher:          ; sw = 11
    cmp byte ptr p_boh, 0A0h
    jb @WriteDirectValue_TwoBytesNoZero
    mov al, '0'                         ; '0' before high-order byte
    call WriteChar
@WriteDirectValue_TwoBytesNoZero:
    mov al, p_boh
    call ByteToHex
    jmp @WriteDirectValue_OnlyOne
@WriteDirectValue_OnlyOneZeroCheck:
    cmp byte ptr p_bol, 0A0h
    jb @WriteDirectValue_OnlyOne
    mov al, '0'                         ; '0' before low-order byte
    call WriteChar
@WriteDirectValue_OnlyOne:              ; w = 0
    mov al, p_bol
    call ByteToHex
    mov al, 'h'
    call WriteChar
    pop ax
    ret
ENDP WriteDirectValue
;---------------------------------------------------------------------
; Prints segment register name
WriteSr PROC
    push ax
    push bx
    mov bx, offset ptr_SREG
    add bl, p_sr
    add bl, p_sr
    mov ax, [bx]
    call WriteString
    mov byte ptr p_sr, -1
    pop bx
    pop ax
    ret
ENDP
;---------------------------------------------------------------------
; Prints one character (al) to output buffer
WriteChar PROC
    push bx
    mov bx, offset OutputBuffer
    add bx, di
    mov [bx], al
    inc di
    inc OutputBuffer
    pop bx
    ret
WriteChar ENDP
;---------------------------------------------------------------------
; Prints string starting at ax and ending by '\0'
WriteString PROC
    push si
    push bx
    push cx
    mov si, ax
    mov bx, offset OutputBuffer
    add bx, di    
@WriteStringLoop:
    mov cl, byte ptr [si]
    mov byte ptr [bx], cl
    inc di
    inc si
    inc bx
    inc OutputBuffer
    cmp byte ptr [si], 0
    jne @WriteStringLoop
    pop cx
    pop bx
    pop si
    ret
ENDP
;---------------------------------------------------------------------
; Command recognition - write line number, bytes, name, arguments...
RecogniseCmd PROC
    mov word ptr FirstByteAddress, offset InputBuffer
    add word ptr FirstByteAddress, si
    cmp byte ptr p_sr, -1
    jne @RecogniseCmd_Continue
    mov OutPutBuffer, 0
    mov di, 1
    ;---------------------------------------
    ; write line number ("xxxx:    ")
    call WriteLineNumber
    ;---------------------------------------
@RecogniseCmd_Continue:
    call ReadByte
    mov bh, 0 
    ;---------------------------------------
    ; check the first byte and determine the command
    mov bx, FirstByteAddress
    mov dl, byte ptr [bx]
    mov dh, 0
    add dx, dx           ; double, because there will be words (adresses)
    add dx, offset fptrptr
    mov bx, dx
    mov bx, [bx]
    mov bx, [bx]
    call bx
    ; remove already used prefix from the next command
    mov bx, FirstByteAddress
    mov bl, [bx]
    and bl, 11100111b
    cmp bl, 00100110b
    je @FinalEnd
    mov byte ptr p_sr, -1
@FinalEnd:
    mov byte ptr p_s, 0
    mov byte ptr f_num, 0
    ret
ENDP RecogniseCmd
;---------------------------------------------------------------------
; Gets destination (d) bit from byte, pointed by FirstByteAddress
Parse_D PROC
    push bx
    push cx
    ; begin parsing
    mov bx, FirstByteAddress
    mov cl, [bx]
    and cl, 00000010b
    shr cl, 1
    mov bx, offset p_d
    mov [bx], cl
    mov bx, offset p_s
    mov [bx], cl
    ; end of parsing
    pop cx
    pop bx
    ret
ENDP Parse_D
;---------------------------------------------------------------------
; Gets width (w) bit from byte, pointed by FirstByteAddress
Parse_W PROC
    push bx
    push cx
    ; begin parsing
    mov bx, FirstByteAddress
    mov cl, [bx]
    and cl, 00000001b
    mov bx, offset p_w
    mov [bx], cl
    ; end of parsing
    pop cx
    pop bx
    ret
ENDP Parse_W
;---------------------------------------------------------------------
; Gets mod, reg and r/m values from byte, pointed by FirstByteAddress+1
Parse_ModRegRm PROC
    push ax
    push bx
    ;push cx
    ; begin parsing
    mov bx, FirstByteAddress
    mov al, [bx+1]          ; al is the modregrm byte
    mov ah, al              ; copy of al
    ; parse "mod"
    mov bx, offset p_mod      ; adress of destination
    and al, 11000000b
    shr al, 6
    mov [bx], al
    ; parse "reg"
    mov bx, offset p_reg      ; adress of destination
    mov al, ah
    and al, 00111000b
    shr al, 3
    mov [bx], al
    ; parse "mod"
    mov bx, offset p_rm      ; adress of destination
    mov al, ah
    and al, 00000111b
    mov [bx], al
    ; end of parsing
    ;pop cx
    pop bx
    pop ax
    ret
ENDP Parse_ModRegRm
;---------------------------------------------------------------------
; Reads the offset (0, 1 or 2 bytes)
ParseOffset PROC
    push ax
    cmp p_mod, 11b
    je @ParseOffset_NoMore
    cmp p_mod, 00b
    jne @ParseOffset_Get
    cmp p_rm, 110b
    jne @ParseOffset_Get
    call ReadByte
    mov p_off_l, al
    call ReadByte
    mov p_off_h, al
@ParseOffset_Get:
    cmp p_mod, 00b
    je @ParseOffset_NoMore
    call ReadByte                       ; read first byte
    mov p_off_l, al
    cmp p_mod, 01b
    je @ParseOffset_NoMore
    call ReadByte                       ; read second byte
    mov p_off_h, al
@ParseOffset_NoMore: 
    pop ax
    ret
ParseOffset ENDP
;---------------------------------------------------------------------
; Parse a variable for "byte ptr" or "word ptr"
ParsePtrName PROC
    mov byte ptr f_num, 1
    cmp byte ptr p_w, 1
    jne ParsePtrName_End
    mov byte ptr f_num, 2
ParsePtrName_End:
    ret
ParsePtrName ENDP
;---------------------------------------------------------------------
; Parse direct value
ParseDirectValue PROC
    mov bx, FirstByteAddress
    mov bl, [bx]
    and bl, 11111110b
    cmp bl, 11000110b
    jne @ParseDirectValue_WithS
    mov byte ptr p_s, 0
@ParseDirectValue_WithS:
    ; read direct value
    call ReadByte
    mov p_bol, al                       ; low-order byte of direct value
    cmp p_w, 0
    je @ParseDirectValue_EndReading
    cmp p_s, 1                          ; when sw = 11, only one byte
    je @ParseDirectValue_EndReading
    call ReadByte                       ; read one more byte if w = 1
    mov p_boh, al                       ; high-order byte of direct value
@ParseDirectValue_EndReading:
    ret
ParseDirectValue ENDP
;=====================================================================
; COMMAND PROCESSING FUNCTIONS
;---------------------------------------------------------------------
; Conditional jumps - JO, JA, JNE, ....
; LOOP, LOOPE, LOOPNE xxxx
; JCXZ xxxx
; Near close direct JMP xxxx
; NEar direct JMP and CALL (offset_l offset_h)
Cmd_Opc_Offset PROC
    ; print the first byte - command name
    call ReadByte           ; read one more byte (offset)
    mov bx, FirstByteAddress    ; get first byte adress
    mov cl, [bx]                ; cl - first byte
    ; read one more byte if needed
    cmp byte ptr [bx], 0E8h
    je @Cmd_Opc_Offset_OneMore
    cmp byte ptr [bx], 0E9h
    je @Cmd_Opc_Offset_OneMore
    jmp @Cmd_Opc_Offset_NoMore
@Cmd_Opc_Offset_OneMore:
    call ReadByte
@Cmd_Opc_Offset_NoMore:    
    ; check if it is a conditional jump, LOOP, JCXZ or JMP
    cmp cl, 0E0h
    je @Cmd_LOOPNE
    cmp cl, 0E1h
    je @Cmd_LOOPE
    cmp cl, 0E2h
    je @Cmd_LOOP
    cmp cl, 0E3h
    je @Cmd_JCXZ
    cmp cl, 0E8h
    je @Cmd_CALL_near_direct
    cmp cl, 0E9h
    je @Cmd_JMP_near_direct
    cmp cl, 0EBh
    je @Cmd_JMP_close_direct
    ; conditional jumps
    and cl, 00001111b           ; we need only the last 4 bits to recognise command 
    mov ax, offset c_CONDJMP    ; ax - conditional jumps' pointers offset
    add al, cl                  ; this jump's pointer's offset
    add al, cl                  ; avoid + 2 * cl
    mov bx, ax                  ; bx is the jumper's name pointer's offset
    mov ax, [bx]                ; get adress of the name
    jmp @Opc_Offset_Name
@Cmd_LOOPNE:
    mov ax, offset c_LOOPN
    jmp @Opc_Offset_Name
@Cmd_LOOPE:
    mov ax, offset c_LOOPE
    jmp @Opc_Offset_Name
@Cmd_LOOP:
    mov ax, offset c_LOOP
    jmp @Opc_Offset_Name
@Cmd_JCXZ:
    mov ax, offset c_JCXZ
    jmp @Opc_Offset_Name
@Cmd_CALL_near_direct:
    mov ax, offset c_CALL
    jmp @Opc_Offset_Name
@Cmd_JMP_near_direct:
    mov ax, offset c_JMP
    jmp @Opc_Offset_Name
@Cmd_JMP_close_direct:
    mov ax, offset c_JMP
    jmp @Opc_Offset_Name
@Opc_Offset_Name:
    call WriteCmdName           ; writes name and sets argument's beginning adress (si) to 33
    ; print the offset
    mov bx, FirstByteAddress
    mov cl, [bx+1]
    ; check length of the offset - 1 or 2 bytes
    cmp byte ptr [bx], 0E8h
    je @Cmd_Opc_Offset_TwoBytes
    cmp byte ptr [bx], 0E9h
    je @Cmd_Opc_Offset_TwoBytes
    mov ch, 0                   ; offset is one byte length
    ; extend by sign byte
    cmp cl, 80h
    jb @Cmd_Opc_Offset_Sum
    mov ch, 0FFh
    jmp @Cmd_Opc_Offset_Sum
@Cmd_Opc_Offset_TwoBytes:
    mov ch, [bx+2]              ; offset is two bytes length
@Cmd_Opc_Offset_Sum:
    add cx, CmdLine
    mov al, ch 
    call ByteToHex
    mov al, cl
    call ByteToHex
    ret
ENDP Cmd_Opc_Offset
;---------------------------------------------------------------------
; Commands ADD, SUB, CMP, OR, ADC, SBB, AND, XOR and MOV (2 formats)
; TEST, XCHG, LEA, LES, LDS
; Format: opk_d_w mod_reg_r/m offset
Cmd_Opc_D_W_Mod_Reg_Rm_Offset PROC
    ; Read at least 1 more byte
    call ReadByte
    mov bx, FirstByteAddress    ; get first byte adress
    mov cl, [bx]                ; cl - first bytes
    ; get all parameters from machine code
    call Parse_D
    call Parse_W
    call Parse_ModRegRm
    call ParseOffset 
    ; check if it is ADD, SUB, CMP or MOV and output command name
    cmp cl, 03h
    jbe @Cmd_ADD_reg_rm
    cmp cl, 0Bh
    jbe @Cmd_OR_reg_rm
    cmp cl, 13h
    jbe @Cmd_ADC_reg_rm
    cmp cl, 1Bh
    jbe @Cmd_SBB_reg_rm
    cmp cl, 23h
    jbe @Cmd_AND_reg_rm
    cmp cl, 2Bh
    jbe @Cmd_SUB_reg_rm
    cmp cl, 33h
    jbe @Cmd_XOR_reg_rm
    cmp cl, 3Bh
    jbe @Cmd_CMP_reg_rm
    cmp cl, 85h
    jbe @Cmd_TEST_reg_rm
    cmp cl, 87h
    jbe @Cmd_XCHG_reg_rm
    cmp cl, 8Ch
    jbe @Cmd_MOV_reg_rm_sr
    cmp cl, 8Dh
    jbe @Cmd_LEA_reg_rm
    cmp cl, 8Eh
    jbe @Cmd_MOV_reg_rm_sr
    cmp cl, 0C4h
    jbe @Cmd_LES_reg_rm
    cmp cl, 0C5h
    jbe @Cmd_LDS_reg_rm
@Cmd_ADD_reg_rm:
    mov ax, offset c_ADD
    jmp @Opc_D_W_Mod_Reg_Rm_Offset_Name
@Cmd_OR_reg_rm:
    mov ax, offset c_OR
    jmp @Opc_D_W_Mod_Reg_Rm_Offset_Name
@Cmd_ADC_reg_rm:
    mov ax, offset c_ADC
    jmp @Opc_D_W_Mod_Reg_Rm_Offset_Name
@Cmd_SBB_reg_rm:
    mov ax, offset c_SBB
    jmp @Opc_D_W_Mod_Reg_Rm_Offset_Name
@Cmd_AND_reg_rm:
    mov ax, offset c_AND
    jmp @Opc_D_W_Mod_Reg_Rm_Offset_Name
@Cmd_SUB_reg_rm:
    mov ax, offset c_SUB
    jmp @Opc_D_W_Mod_Reg_Rm_Offset_Name
@Cmd_XOR_reg_rm:
    mov ax, offset c_XOR
    jmp @Opc_D_W_Mod_Reg_Rm_Offset_Name
@Cmd_CMP_reg_rm:
    mov ax, offset c_CMP
    jmp @Opc_D_W_Mod_Reg_Rm_Offset_Name
@Cmd_TEST_reg_rm:
    mov ax, offset c_TEST
    jmp @Opc_D_W_Mod_Reg_Rm_Offset_Name
@Cmd_XCHG_reg_rm:
    mov ax, offset c_XCHG
    jmp @Opc_D_W_Mod_Reg_Rm_Offset_Name
@Cmd_LEA_reg_rm:
    mov byte ptr p_d, 1                     ; this command's result can be saved only in the register
    mov ax, offset c_LEA
    jmp @Opc_D_W_Mod_Reg_Rm_Offset_Name
@Cmd_MOV_reg_rm_sr:
    mov ax, offset c_MOV
    jmp @Opc_D_W_Mod_Reg_Rm_Offset_Name  
@Cmd_LES_reg_rm:
    mov byte ptr p_d, 1                     ; this command's result can be saved only in the register
    mov byte ptr p_w, 1                     ; the register is 2 bytes length
    mov ax, offset c_LES
    jmp @Opc_D_W_Mod_Reg_Rm_Offset_Name
@Cmd_LDS_reg_rm:
    mov byte ptr p_d, 1                     ; this command's result can be saved only in the register
    mov ax, offset c_LDS
    jmp @Opc_D_W_Mod_Reg_Rm_Offset_Name
@Opc_D_W_Mod_Reg_Rm_Offset_Name:
    call WriteCmdName                   ; write command name to output file
    ; check special case of MOV with segment register
    cmp cl, 8Ch
    je @Cmd_Opc_D_W_Mod_Reg_Rm_Offset_MOVsr
    cmp cl, 8Eh
    je @Cmd_Opc_D_W_Mod_Reg_Rm_Offset_MOVsr
    ;---------------------------------
    call WriteRegRmArguments
    jmp @Cmd_Opc_D_W_Mod_Reg_Rm_Offset_End
    ;---------------------------------
    ; MOV format with segment register
@Cmd_Opc_D_W_Mod_Reg_Rm_Offset_MOVsr:
    mov bx, FirstByteAddress
    mov bl, [bx+1]
    and bl, 00011000b
    shr bl, 3
    add bl, bl
    mov bh, 0
    add bx, offset ptr_SREG
    mov ax, [bx]
    mov p_w, 1
    cmp p_d, 0
    je @Cmd_MOV_sr_reversed
    call WriteString                        ; prints segment register
    call WriteSeparator
    call WriteRm
    jmp @Cmd_Opc_D_W_Mod_Reg_Rm_Offset_End
@Cmd_MOV_sr_reversed:
    call WriteRm
    call WriteSeparator
    call WriteString                        ; prints segment register
    ;--------------------------------
@Cmd_Opc_D_W_Mod_Reg_Rm_Offset_End:
    ret
ENDP Cmd_Opc_D_W_Mod_Reg_Rm_Offset
;---------------------------------------------------------------------
; Commands ADD, SUB, CMP, OR, ADC, SBB, AND, XOR, TEST, RETF with ax, MOV with reg
; Format: opk_w b_op_l b_op_h
Cmd_Opc_Bop PROC
    ; Read at least 1 more byte
    call ReadByte
    mov bx, FirstByteAddress
    mov cl, [bx]
    mov ch, [bx+1]
    mov p_bol, ch                       ; low-order direct value byte
    call Parse_W
    mov byte ptr p_reg, 000b                     ; register is ax (al)
    ; check special case of retf
    cmp cl, 0CAh
    jne @Cmd_Opc_Bop_CheckMov
    mov byte ptr p_w, 1
    jmp @Cmd_Opc_Bop_NotWMov
@Cmd_Opc_Bop_CheckMov:
    ; check special case when it is MOV with w in opc as a 5th bit
    cmp cl, 0B0h
    jb @Cmd_Opc_Bop_NotWMov
    cmp cl, 0BFh
    ja @Cmd_Opc_Bop_NotWMov
    ; parse w of MOV
    mov dl, cl
    and dl, 00001000b
    shr dl, 3
    mov p_w, dl
    ; parse reg of MOV
    mov dl, cl
    and dl, 00000111b
    mov p_reg, dl
@Cmd_Opc_Bop_NotWMov:
    cmp p_w, 0
    je @Opc_Bop_NoMore
    mov ch, [bx+2]
    mov p_boh, ch                       ; high-order direct value byte
    call ReadByte                       ; read one more byte if w = 1
@Opc_Bop_NoMore:    
    cmp cl, 05h
    jbe @Cmd_ADD_bop
    cmp cl, 0Dh
    jbe @Cmd_OR_bop
    cmp cl, 15h
    jbe @Cmd_ADC_bop
    cmp cl, 1Dh
    jbe @Cmd_SBB_bop
    cmp cl, 25h
    jbe @Cmd_AND_bop
    cmp cl, 2Dh
    jbe @Cmd_SUB_bop
    cmp cl, 35h
    jbe @Cmd_XOR_bop
    cmp cl, 3Dh
    jbe @Cmd_CMP_bop
    cmp cl, 0A9h
    jbe @Cmd_TEST_bop
    cmp cl, 0BFh
    jbe @Cmd_MOV_reg_dirval
    cmp cl, 0CAh
    jbe @Cmd_RETF_bop
@Cmd_ADD_bop:
    mov ax, offset c_ADD
    jmp @Opc_Bop_Name
@Cmd_OR_bop:
    mov ax, offset c_OR
    jmp @Opc_Bop_Name
@Cmd_ADC_bop:
    mov ax, offset c_ADC
    jmp @Opc_Bop_Name
@Cmd_SBB_bop:
    mov ax, offset c_SBB
    jmp @Opc_Bop_Name
@Cmd_AND_bop:
    mov ax, offset c_AND
    jmp @Opc_Bop_Name
@Cmd_SUB_bop:
    mov ax, offset c_SUB
    jmp @Opc_Bop_Name
@Cmd_XOR_bop:
    mov ax, offset c_XOR
    jmp @Opc_Bop_Name
@Cmd_CMP_bop:
    mov ax, offset c_CMP
    jmp @Opc_Bop_Name
@Cmd_TEST_bop:
    mov ax, offset c_TEST
    jmp @Opc_Bop_Name
@Cmd_MOV_reg_dirval:
    mov ax, offset c_MOV
    jmp @Opc_Bop_Name
@Cmd_RETF_bop:
    mov ax, offset c_RETF
    jmp @Opc_Bop_Name
@Opc_Bop_Name:
    call WriteCmdName
    ; check special case when retf is used (ax is not needed)
    cmp cl, 0CAh
    je @Opc_Bop_OnlyValue
    call WriteReg
    call WriteSeparator
@Opc_Bop_OnlyValue:
    call WriteDirectValue
    ret
ENDP Cmd_Opc_Bop
;---------------------------------------------------------------------
; Commands PUSH sr, POP sr, and prefix
; Format: opk_sr_opk
Cmd_Opc_Sr_Opc PROC
    ; output command name
    mov bx, FirstByteAddress
    mov cl, [bx]
    ; parse sr
    mov ch, cl
    and ch, 00011000b
    shr ch, 3
    mov byte ptr p_sr, ch
    ; look for command
    mov ch, cl
    and ch, 00100111b
    cmp ch, 00000110b
    je @Cmd_PUSH_sr
    cmp ch, 00000111b
    je @Cmd_POP_sr
    jmp @Opc_Sr_Opc_End
@Cmd_PUSH_sr:
    mov ax, offset c_PUSH
    jmp @Opc_Sr_Opc_Name
@Cmd_POP_sr:
    mov ax, offset c_POP
    jmp @Opc_Sr_Opc_Name
@Opc_Sr_Opc_Name:
    call WriteCmdName
    call WriteSr
@Opc_Sr_Opc_End:
    ret
ENDP Cmd_Opc_Sr_Opc
;---------------------------------------------------------------------
; Commands INC, DEC, PUSH, POP, XCHG (ax,) with registers
; Format: opk_reg
Cmd_Opc_Reg PROC
    mov bx, FirstByteAddress
    mov cl, [bx]
    ; parse register
    mov ch, cl
    and ch, 00000111b
    mov p_reg, ch
    mov byte ptr p_w, 1
    ; parse the command name
    cmp cl, 47h
    jbe @Cmd_INC_reg
    cmp cl, 4Fh
    jbe @Cmd_DEC_reg
    cmp cl, 57h
    jbe @Cmd_PUSH_reg
    cmp cl, 5Fh
    jbe @Cmd_POP_reg
    cmp cl, 97h
    jbe @Cmd_XCHG_reg
@Cmd_INC_reg:
    mov ax, offset c_INC
    jmp @Opc_Reg_Name
@Cmd_DEC_reg:
    mov ax, offset c_DEC
    jmp @Opc_Reg_Name
@Cmd_PUSH_reg:
    mov ax, offset c_PUSH
    jmp @Opc_Reg_Name
@Cmd_POP_reg:
    mov ax, offset c_POP
    jmp @Opc_Reg_Name
@Cmd_XCHG_reg:
    mov ax, offset c_XCHG
    jmp @Opc_Reg_Name
@Opc_Reg_Name:
    call WriteCmdName
    ; special case of XCHG - ax needed
    cmp cl, 90h
    jb @Cmd_Opc_Reg_NoAx
    mov ax, offset r_AX
    call WriteString
    call WriteSeparator
@Cmd_Opc_Reg_NoAx:    
    call WriteReg
    ret
ENDP Cmd_Opc_Reg
;---------------------------------------------------------------------
; Commands ADD, SUB, CMP, OR, ADC, SBB, AND, XOR, MOV with direct value
; Format: opc_s_w mod_opc_reg [offset] bop
Cmd_Opc_S_W_Mod_Opc_Rm_Offset_Bop PROC
    call ReadByte                       ; read mod_opc_reg byte
    call Parse_D   
    call Parse_W
    call Parse_ModRegRm
    call ParseOffset
    call ParsePtrName
    call ParseDirectValue
    ; parse names and check validity
    mov bx, FirstByteAddress
    mov cl, [bx]
    mov ch, byte ptr p_reg
    cmp cl, 83h
    ja @Opc_S_W_Mod_Opc_Rm_Offset_Bop_IsMov ; check extension of opcode when command is ADD, SUB and CMP
    cmp ch, 000b
    je @Cmd_ADD_dirvalue
    cmp ch, 001b
    je @Cmd_OR_dirvalue
    cmp ch, 010b 
    je @Cmd_ADC_dirvalue
    cmp ch, 011b
    je @Cmd_SBB_dirvalue
    cmp ch, 100b
    je @Cmd_AND_dirvalue
    cmp ch, 101b
    je @Cmd_SUB_dirvalue
    cmp ch, 110b
    je @Cmd_XOR_dirvalue
    cmp ch, 111b
    je @Cmd_CMP_dirvalue
    jmp @Opc_S_W_Mod_Opc_Rm_Offset_Bop_Unknown
@Opc_S_W_Mod_Opc_Rm_Offset_Bop_IsMov:        ; check extension of opcode of MOV
    cmp ch, 000b
    je @Cmd_MOV_dirval
    jmp @Opc_S_W_Mod_Opc_Rm_Offset_Bop_Unknown
@Opc_S_W_Mod_Opc_Rm_Offset_Bop_Unknown:
    call CmdUnknownCmd
    jmp @Opc_S_W_Mod_Opc_Rm_Offset_Bop_End
    ; if no 
@Cmd_ADD_dirvalue:
    mov ax, offset c_ADD
    jmp @Opc_S_W_Mod_Opc_Rm_Offset_Bop_Name
@Cmd_OR_dirvalue:
    mov ax, offset c_OR
    jmp @Opc_S_W_Mod_Opc_Rm_Offset_Bop_Name
@Cmd_ADC_dirvalue:
    mov ax, offset c_ADC
    jmp @Opc_S_W_Mod_Opc_Rm_Offset_Bop_Name
@Cmd_SBB_dirvalue:
    mov ax, offset c_SBB
    jmp @Opc_S_W_Mod_Opc_Rm_Offset_Bop_Name
@Cmd_AND_dirvalue:
    mov ax, offset c_AND
    jmp @Opc_S_W_Mod_Opc_Rm_Offset_Bop_Name
@Cmd_SUB_dirvalue:
    mov ax, offset c_SUB
    jmp @Opc_S_W_Mod_Opc_Rm_Offset_Bop_Name
@Cmd_CMP_dirvalue:
    mov ax, offset c_CMP
    jmp @Opc_S_W_Mod_Opc_Rm_Offset_Bop_Name
@Cmd_XOR_dirvalue:
    mov ax, offset c_XOR
    jmp @Opc_S_W_Mod_Opc_Rm_Offset_Bop_Name
@Cmd_MOV_dirval:
    mov ax, offset c_MOV
    jmp @Opc_S_W_Mod_Opc_Rm_Offset_Bop_Name
@Opc_S_W_Mod_Opc_Rm_Offset_Bop_Name:
    call WriteCmdName
    call WriteRm
    call WriteSeparator
    call WriteDirectValue
@Opc_S_W_Mod_Opc_Rm_Offset_Bop_End:
    ret
ENDP Cmd_Opc_S_W_Mod_Opc_Rm_Offset_Bop
;---------------------------------------------------------------------
; Commands NOT, NEG, (I)MUL, (I)DIV, INC, DEC, indirect CALLs, JMPs and PUSH
; ROL, ROR, RCL, RCR, SHL, SHR, SAR, POP
; Format: opc_(v)(w) mod_opc_rm [offset]
Cmd_Opc_W_Mod_Opc_Rm_Offset PROC
    call ReadByte                       ; read mod_opc_reg byte
    call Parse_W
    call Parse_ModRegRm
    call ParseOffset
    call ParsePtrName
    ; parse names and check validity
    mov bx, FirstByteAddress
    mov cl, [bx]
    mov ch, p_reg
    cmp cl, 8Fh
    je @Cmd_POP_rm
    cmp cl, 0D3h
    ja @Opc_W_Mod_Opc_Rm_Offset_CheckF7
    cmp ch, 000b
    je @Cmd_ROL
    cmp ch, 001b
    je @Cmd_ROR
    cmp ch, 010b
    je @Cmd_RCL
    cmp ch, 011b
    je @Cmd_RCR
    cmp ch, 100b
    je @Cmd_SHL
    cmp ch, 101b
    je @Cmd_SHR
    cmp ch, 111b
    je @Cmd_SAR
    jmp @Opc_W_Mod_Opc_Rm_Offset_Unknown
@Opc_W_Mod_Opc_Rm_Offset_CheckF7:
    cmp cl, 0F7h
    ja @Opc_W_Mod_Opc_Rm_Offset_CheckFF
    ; check opcode extension in second byte of commands F6-F7
    cmp ch, 000b
    je @Cmd_TEST_rm_bop
    cmp ch, 010b
    je @Cmd_NOT
    cmp ch, 011b
    je @Cmd_NEG
    cmp ch, 100b
    je @Cmd_MUL
    cmp ch, 101b
    je @Cmd_IMUL
    cmp ch, 110b
    je @Cmd_DIV
    cmp ch, 111b
    je @Cmd_IDIV
    jmp @Opc_W_Mod_Opc_Rm_Offset_Unknown
    ; check opcode extension in second byte of commands FE-FF
@Opc_W_Mod_Opc_Rm_Offset_CheckFF:
    cmp ch, 000b
    je @Cmd_INC_rm
    cmp ch, 001b
    je @Cmd_DEC_rm
    cmp ch, 011b
    jbe @Cmd_CALL_indirect
    cmp ch, 101b
    jbe @Cmd_JMP_indirect
    cmp ch, 110b
    je @Cmd_PUSH_rm
    jmp @Opc_W_Mod_Opc_Rm_Offset_Unknown
@Cmd_POP_rm:
    cmp ch, 000b
    jne @Opc_W_Mod_Opc_Rm_Offset_Unknown
    mov ax, offset c_POP
    jmp @Opc_W_Mod_Opc_Rm_Offset_Name
@Cmd_ROL:
    mov ax, offset c_ROL
    jmp @Opc_W_Mod_Opc_Rm_Offset_Name
@Cmd_ROR:
    mov ax, offset c_ROR
    jmp @Opc_W_Mod_Opc_Rm_Offset_Name
@Cmd_RCL:
    mov ax, offset c_RCL
    jmp @Opc_W_Mod_Opc_Rm_Offset_Name
@Cmd_RCR:
    mov ax, offset c_RCR
    jmp @Opc_W_Mod_Opc_Rm_Offset_Name
@Cmd_SHL:
    mov ax, offset c_SHL
    jmp @Opc_W_Mod_Opc_Rm_Offset_Name
@Cmd_SHR:
    mov ax, offset c_SHR
    jmp @Opc_W_Mod_Opc_Rm_Offset_Name
@Cmd_SAR:
    mov ax, offset c_SAR
    jmp @Opc_W_Mod_Opc_Rm_Offset_Name
@Cmd_TEST_rm_bop:
    call ParseDirectValue
    mov ax, offset c_TEST
    jmp @Opc_W_Mod_Opc_Rm_Offset_Name
@Cmd_NOT:
    mov ax, offset c_NOT
    jmp @Opc_W_Mod_Opc_Rm_Offset_Name
@Cmd_NEG:
    mov ax, offset c_NEG
    jmp @Opc_W_Mod_Opc_Rm_Offset_Name
@Cmd_MUL:
    mov ax, offset c_MUL
    jmp @Opc_W_Mod_Opc_Rm_Offset_Name
@Cmd_IMUL:
    mov ax, offset c_IMUL
    jmp @Opc_W_Mod_Opc_Rm_Offset_Name
@Cmd_DIV:
    mov ax, offset c_DIV
    jmp @Opc_W_Mod_Opc_Rm_Offset_Name
@Cmd_IDIV:
    mov ax, offset c_IDIV
    jmp @Opc_W_Mod_Opc_Rm_Offset_Name
@Cmd_INC_rm:
    mov ax, offset c_INC
    jmp @Opc_W_Mod_Opc_Rm_Offset_Name
@Cmd_DEC_rm:  
    mov ax, offset c_DEC
    jmp @Opc_W_Mod_Opc_Rm_Offset_Name
@Cmd_CALL_indirect:
    mov ax, offset c_CALL
    jmp @Opc_W_Mod_Opc_Rm_Offset_Name
@Cmd_JMP_indirect:
    mov ax, offset c_JMP
    jmp @Opc_W_Mod_Opc_Rm_Offset_Name  
@Cmd_PUSH_rm:
    mov ax, offset c_PUSH
    jmp @Opc_W_Mod_Opc_Rm_Offset_Name
@Opc_W_Mod_Opc_Rm_Offset_Unknown:
    call CmdUnknownCmd
    jmp @Opc_W_Mod_Opc_Rm_Offset_End    
@Opc_W_Mod_Opc_Rm_Offset_Name:
    call WriteCmdName
    call WriteRm
    cmp cl, 0D0h
    jb @Opc_W_Mod_Opc_Rm_Offset_End
    cmp cl, 0D3h
    ja @Opc_W_Mod_Opc_Rm_Offset_CheckTest
    ; if it is command for rotating or shifting, add cl or 1
    call WriteSeparator
    call Parse_D                    ; 'v' bit will be saved in d (to use existing variables)
    cmp byte ptr p_d, 0
    jne @Opc_W_Mod_Opc_Rm_Offset_CL
    mov al, '1'
    call WriteChar
    jmp @Opc_W_Mod_Opc_Rm_Offset_End
@Opc_W_Mod_Opc_Rm_Offset_CL:
    mov ax, offset r_CL
    call WriteString
    jmp @Opc_W_Mod_Opc_Rm_Offset_End
@Opc_W_Mod_Opc_Rm_Offset_CheckTest:
    cmp cl, 0F7h
    ja @Opc_W_Mod_Opc_Rm_Offset_End
    cmp byte ptr p_reg, 000b
    jne @Opc_W_Mod_Opc_Rm_Offset_End
    ; if the command is TEST, print direct value
    call WriteSeparator
    call WriteDirectValue
    jmp @Opc_W_Mod_Opc_Rm_Offset_End
@Opc_W_Mod_Opc_Rm_Offset_End:
    ret
Cmd_Opc_W_Mod_Opc_Rm_Offset ENDP
;---------------------------------------------------------------------
; Commands MOV ax, r/m and MOV r/m, ax
; Format: opc_w adr_l adr_h
Cmd_Opc_W_Rm PROC
    call ReadByte                       ; read low-order adress byte
    call ReadByte                       ; read high-order adress byte
    call Parse_W
    mov byte ptr p_mod, 00b
    mov byte ptr p_reg, 000b
    mov byte ptr p_rm, 110b
    ; print name
    mov ax, offset c_MOV
    call WriteCmdName
    ; print arguments and parse direct adress
    mov bx, FirstByteAddress
    mov al, [bx+1]  
    mov p_off_l, al
    mov al, [bx+2]
    mov p_off_h, al
    cmp byte ptr [bx], 0A1h
    ja @Cmd_Opc_W_Rm_OppositeOrder
    ; the command first byte is A0-A1
    call WriteReg
    call WriteSeparator
    call WriteRm
    jmp @Cmd_Opc_W_Rm_End
@Cmd_Opc_W_Rm_OppositeOrder:   
    ; the command first byte is A2-A3
    call WriteRm
    call WriteSeparator
    call WriteReg
@Cmd_Opc_W_Rm_End:
    ret
Cmd_Opc_W_Rm ENDP
;---------------------------------------------------------------------
; Commands CALL and JUMP far direct
; Format: opc adr_l adr_h seg_l seg_h
Cmd_Opc_Adr_Seg PROC
    call ReadByte                   ; read low-order offset adress byte
    call ReadByte                   ; read high-order offset adress byte
    call ReadByte                   ; read low-order segment adress byte
    call ReadByte                   ; read high-order segment adress byte
    mov bx, FirstByteAddress
    cmp byte ptr [bx], 9Ah
    je @Cmd_CALL_far_direct
    jmp @Cmd_JMP_far_direct
@Cmd_CALL_far_direct:
    mov ax, offset c_CALL
    jmp @Cmd_Opc_Adr_Seg_Name
@Cmd_JMP_far_direct:
    mov ax, offset c_JMP
    jmp @Cmd_Opc_Adr_Seg_Name
@Cmd_Opc_Adr_Seg_Name:
    call WriteCmdName
    mov byte ptr p_w, 1             ; the size of values is two bytes
    mov byte ptr p_s, 0             ; not to extend by sign
    ; write segment adress
    mov al, [bx+4]
    mov p_boh, al
    mov al, [bx+3]
    mov p_bol, al
    call WriteDirectValue
    ; write ':'
    mov al, ':'
    call WriteChar
    ; write offset adress
    mov al, [bx+2]
    mov p_boh, al
    mov al, [bx+1]
    mov p_bol, al
    call WriteDirectValue
    ret
Cmd_Opc_Adr_Seg ENDP
;---------------------------------------------------------------------
; Command INT, IN, OUT number
; Format: opc number
Cmd_Opc_Number PROC
    call Parse_W
    mov cl, byte ptr p_w
    mov byte ptr p_d, cl            ; using 'd' for saving w
    mov byte ptr p_reg, 000b
    mov byte ptr p_w, 0
    call ParseDirectValue
    mov bx, FirstByteAddress
    mov cl, [bx]
    cmp cl, 0CDh
    je @Cmd_INT
    cmp cl, 0E5h
    jbe @Cmd_IN_num
    cmp cl, 0E7h
    jbe @Cmd_OUT_num
@Cmd_INT:
    mov ax, offset c_INT
    call WriteCmdName
    call WriteDirectValue
    jmp @Cmd_Opc_Number_End
@Cmd_IN_num:
    mov ax, offset c_IN
    call WriteCmdName
    mov cl, byte ptr p_d
    mov byte ptr p_w, cl
    call WriteReg
    call WriteSeparator
    mov byte ptr p_w, 0
    call WriteDirectValue
    jmp @Cmd_Opc_Number_End
@Cmd_OUT_num:
    mov ax, offset c_OUT
    call WriteCmdName
    call WriteDirectValue  
    call WriteSeparator    
    mov cl, byte ptr p_d
    mov byte ptr p_w, cl
    call WriteReg   
    jmp @Cmd_Opc_Number_End
@Cmd_Opc_Number_End:
    ret
Cmd_Opc_Number ENDP
;---------------------------------------------------------------------
; Commands only with opcode:
; DAA, DAS, AAA, AAS, NOP, CBW, CWD, WAIT, PUSHF, POPF, SAHF, LAHF
; RETF, INT 3, INTO, IRET, XLAT, LOCK, REPNZ, REP, HLT, CMC, CLC
; STC, CLI, STI, CLD, STD, IN, OUT
; Format: opc
Cmd_Opc PROC
    mov bx, FirstByteAddress
    mov cl, [bx]
    cmp cl, 27h
    je @Cmd_DAA
    cmp cl, 2Fh
    je @Cmd_DAS
    cmp cl, 37h
    je @Cmd_AAA
    cmp cl, 3Fh
    je @Cmd_AAS
    cmp cl, 90h
    je @Cmd_NOP
    cmp cl, 98h
    je @Cmd_CBW
    cmp cl, 99h
    je @Cmd_CWD
    cmp cl, 9Bh
    je @Cmd_WAIT
    cmp cl, 9Ch
    je @Cmd_PUSHF
    cmp cl, 9Dh
    je @Cmd_POPF
    cmp cl, 9Eh
    je @Cmd_SAHF
    cmp cl, 9Fh
    je @Cmd_LAHF
    cmp cl, 0C3h
    je @Cmd_RET
    cmp cl, 0CBh
    je @Cmd_RETF
    cmp cl, 0CCh
    je @Cmd_INT3
    jmp @Cmd_Opc_2
@Cmd_DAA:
    mov ax, offset c_DAA
    jmp @Cmd_Opc_Name
@Cmd_DAS:
    mov ax, offset c_DAS
    jmp @Cmd_Opc_Name    
@Cmd_AAA:
    mov ax, offset c_AAA
    jmp @Cmd_Opc_Name    
@Cmd_AAS:
    mov ax, offset c_AAS
    jmp @Cmd_Opc_Name    
@Cmd_NOP:
    mov ax, offset c_NOP
    jmp @Cmd_Opc_Name    
@Cmd_CBW:
    mov ax, offset c_CBW
    jmp @Cmd_Opc_Name    
@Cmd_CWD:
    mov ax, offset c_CWD
    jmp @Cmd_Opc_Name    
@Cmd_WAIT:
    mov ax, offset c_WAIT
    jmp @Cmd_Opc_Name    
@Cmd_PUSHF:
    mov ax, offset c_PUSHF
    jmp @Cmd_Opc_Name    
@Cmd_POPF:
    mov ax, offset c_POPF
    jmp @Cmd_Opc_Name    
@Cmd_SAHF:
    mov ax, offset c_SAHF
    jmp @Cmd_Opc_Name    
@Cmd_LAHF:
    mov ax, offset c_LAHF
    jmp @Cmd_Opc_Name  
@Cmd_RET:
    mov ax, offset c_RET
    jmp @Cmd_Opc_Name
@Cmd_RETF:
    mov ax, offset c_RETF
    jmp @Cmd_Opc_Name
@Cmd_INT3:
    mov ax, offset c_INT3
    jmp @Cmd_Opc_Name
@Cmd_Opc_Name:
    call WriteCmdName
    ret                             ; end of first part of commands
    ; second part of commands
@Cmd_Opc_2:
    cmp cl, 0CEh
    je @Cmd_INTO
    cmp cl, 0CFh
    je @Cmd_IRET
    cmp cl, 0D4h
    je @Cmd_AAM
    cmp cl, 0D5h
    je @Cmd_AAD
    cmp cl, 0D7h
    je @Cmd_XLAT
    cmp cl, 0EDh
    jbe @Cmd_IN
    cmp cl, 0EFh
    jbe @Cmd_OUT
    cmp cl, 0F0h
    je @Cmd_LOCK
    cmp cl, 0F2h
    je @Cmd_REPNZ
    cmp cl, 0F3h
    je @Cmd_REP
    cmp cl, 0F4h
    je @Cmd_HLT
    cmp cl, 0F5h
    je @Cmd_CMC
    cmp cl, 0F8h
    je @Cmd_CLC
    cmp cl, 0F9h
    je @Cmd_STC
    cmp cl, 0FAh
    je @Cmd_CLI
    cmp cl, 0FBh
    je @Cmd_STI
    cmp cl, 0FCh
    je @Cmd_CLD
    cmp cl, 0FDh
    je @Cmd_STD
@Cmd_INTO:
    mov ax, offset c_INTO
    jmp @Cmd_Opc_Name2
@Cmd_IRET:
    mov ax, offset c_IRET
    jmp @Cmd_Opc_Name2
@Cmd_AAM:
    call ReadByte
    cmp byte ptr [bx+1], 0Ah
    jne @Cmd_Opc_Unknown
    mov ax, offset c_AAM
    jmp @Cmd_Opc_Name2
@Cmd_AAD:
    call ReadByte
    cmp byte ptr [bx+1], 0Ah
    jne @Cmd_Opc_Unknown
    mov ax, offset c_AAD
    jmp @Cmd_Opc_Name2
@Cmd_XLAT:
    mov ax, offset c_XLAT
    jmp @Cmd_Opc_Name2
@Cmd_IN:
    mov ax, offset c_IN
    jmp @Cmd_Opc_Name2
@Cmd_OUT:
    mov ax, offset c_OUT
    jmp @Cmd_Opc_Name2
@Cmd_LOCK:
    mov ax, offset c_LOCK
    jmp @Cmd_Opc_Name2
@Cmd_REPNZ:
    mov ax, offset c_REPNZ
    jmp @Cmd_Opc_Name2
@Cmd_REP:
    mov ax, offset c_REP
    jmp @Cmd_Opc_Name2
@Cmd_HLT:
    mov ax, offset c_HLT
    jmp @Cmd_Opc_Name2
@Cmd_CMC:
    mov ax, offset c_CMC
    jmp @Cmd_Opc_Name2
@Cmd_CLC:
    mov ax, offset c_CLC
    jmp @Cmd_Opc_Name2
@Cmd_STC:
    mov ax, offset c_STC
    jmp @Cmd_Opc_Name2
@Cmd_CLI:
    mov ax, offset c_CLI
    jmp @Cmd_Opc_Name2
@Cmd_STI:
    mov ax, offset c_STI
    jmp @Cmd_Opc_Name2
@Cmd_CLD:
    mov ax, offset c_CLD
    jmp @Cmd_Opc_Name2
@Cmd_STD:
    mov ax, offset c_STD
    jmp @Cmd_Opc_Name2
@Cmd_Opc_Unknown:
    call CmdUnknownCmd
    jmp @Cmd_Opc_End
@Cmd_Opc_Name2:
    call WriteCmdName
    call Parse_W
    mov byte ptr p_reg, 000b
    ; check special cases of IN and OUT (arguments needed)
    cmp cl, 0ECh
    jb @Cmd_Opc_End
    cmp cl, 0EDh
    ja @Cmd_Opc_EE_EF     
    ; IN ax(al), dx
    call WriteReg
    call WriteSeparator
    mov ax, offset r_DX
    call WriteString
    jmp @Cmd_Opc_End
@Cmd_Opc_EE_EF:
    cmp cl, 0EFh
    ja @Cmd_Opc_End
    mov ax, offset r_DX
    call WriteString
    call WriteSeparator
    call WriteReg
    jmp @Cmd_Opc_End
@Cmd_Opc_End:
    ret
Cmd_Opc ENDP
;---------------------------------------------------------------------
; Commands for string processing: MOVS, CMPS, STOS, LODS, SCAS
; Format: opc
Cmd_Opc_Str PROC
    call Parse_W
    mov bx, FirstByteAddress
    mov cl, [bx]
    cmp cl, 0A5h
    jbe @Cmd_MOVS
    cmp cl, 0A7h
    jbe @Cmd_CMPS
    cmp cl, 0ABh
    jbe @Cmd_STOS
    cmp cl, 0ADh
    jbe @Cmd_LODS
    cmp cl, 0AFh
    jbe @Cmd_SCAS
@Cmd_MOVS:
    mov ax, offset c_MOVS
    jmp @Cmd_Opc_Str_Name
@Cmd_CMPS:
    mov ax, offset c_CMPS
    jmp @Cmd_Opc_Str_Name
@Cmd_STOS:
    mov ax, offset c_STOS
    jmp @Cmd_Opc_Str_Name
@Cmd_LODS:
    mov ax, offset c_LODS
    jmp @Cmd_Opc_Str_Name
@Cmd_SCAS:
    mov ax, offset c_SCAS
    jmp @Cmd_Opc_Str_Name
@Cmd_Opc_Str_Name:
    call WriteCmdName
    mov di, cmdname_begin+5
    mov OutputBuffer, cmdname_begin+4
    cmp byte ptr p_w, 0
    jne @Cmd_Opc_Str_Word
    mov al, 'b'
    jmp @Cmd_Opc_Str_End
@Cmd_Opc_Str_Word:
    mov al, 'w'
@Cmd_Opc_Str_End:
    call WriteChar
    ret
Cmd_Opc_Str ENDP
;---------------------------------------------------------------------
; Command RET value
; Format: opc dirval_l dirval_h
Cmd_Opc_Bopl_Boph PROC
    call ReadByte                   ; read low-order byte of direct value
    call ReadByte                   ; read high-order byte of direct value
    mov ax, offset c_RET
    call WriteCmdName
    mov p_w, 1
    mov bx, FirstByteAddress
    mov al, [bx+2]
    mov p_boh, al
    mov al, [bx+1]
    mov p_bol, al
    call WriteDirectValue
    ret
Cmd_Opc_Bopl_Boph ENDP
;---------------------------------------------------------------------
; Prints unknown command
CmdUnknownCmd PROC
    mov ax, offset c_UNKNOWN
    call WriteCmdName
    ret
ENDP CmdUnknownCmd
;---------------------------------------------------------------------
; Assign pointers to functions
AssignFuncPtr   PROC
    mov Ptr_Cmd_Opc_D_W_Mod_Reg_Rm_Offset, offset Cmd_Opc_D_W_Mod_Reg_Rm_Offset
    mov Ptr_Cmd_Opc_Bop, offset Cmd_Opc_Bop
    mov Ptr_Cmd_Opc_Sr_Opc, offset Cmd_Opc_Sr_Opc
    mov Ptr_Cmd_Opc_Offset, offset Cmd_Opc_Offset
    mov Ptr_Cmd_Opc_S_W_Mod_Opc_Rm_Offset_Bop, offset Cmd_Opc_S_W_Mod_Opc_Rm_Offset_Bop
    mov Ptr_CmdUnknownCmd, offset CmdUnknownCmd
    mov Ptr_Cmd_Opc_Reg, offset Cmd_Opc_Reg
    mov Ptr_Cmd_Opc_W_Mod_Opc_Rm_Offset, offset Cmd_Opc_W_Mod_Opc_Rm_Offset
    mov Ptr_Cmd_Opc_W_Rm, offset Cmd_Opc_W_Rm
    mov Ptr_Cmd_Opc_Adr_Seg, offset Cmd_Opc_Adr_Seg
    mov Ptr_Cmd_Opc_Number, offset Cmd_Opc_Number
    mov Ptr_Cmd_Opc, offset Cmd_Opc
    mov Ptr_Cmd_Opc_Str, offset Cmd_Opc_Str
    mov Ptr_Cmd_Opc_Bopl_Boph, offset Cmd_Opc_Bopl_Boph
    ret
AssignFuncPtr   ENDP
;=====================================================================
;=====================================================================
    jmp Main
Help:
    mov ah, 09h
    mov dx, offset HelpMsg
    int 21h
    jmp Fin
FailedFileOpening:
    mov ah, 09h
    mov dx, offset FailedOpeningMsg
    int 21h
    jmp Fin
NoDataRead:
    mov ah, 09h
    mov dx, offset NoDataMsg
    int 21h
    jmp Fin
;=====================================================================    
Main:
    mov ax, @data
    mov ds, ax
    mov cx, es:[80h]
    cmp cl, 0                           
    je Help
    mov cx, es:[82h]
    cmp cx, "?/"
    je Help
    ;---------------------------------------
    ; Parse files' names
    mov si, 0
    mov bx, offset FileIn
    call GetFileNames
    mov bx, offset FileOut
    call GetFileNames
    ;---------------------------------------
    ; Open input file
    mov al, 0
    mov bx, offset FileInHan
    mov dx, offset FileIn
    call OpenFile
    cmp word ptr [bx], 0
    je FailedFileOpening
    ; Create output file
    mov ah, 3Ch
    mov cx, 0
    mov dx, offset FileOut
    int 21h
    cmp ax, 0
    je FailedFileOpening 
    mov bx, offset FileOutHan
    mov [bx], ax
    ;---------------------------------------
    ; Read input file
    call ReadFile
    mov bx, offset InputBuffer
    cmp byte ptr [bx], 0
    je NoDataRead
    ;---------------------------------------
    call AssignFuncPtr
    mov si, 1
BeginRecognising: 
    call RecogniseCmd
    ;---------------------------------------
    ; write recognised line to result file
    cmp byte ptr p_sr, -1
    jne CheckNext
    mov al, 10
    call WriteChar                      ; add new line at the end of the buffer
    call WriteLineToFile
    cmp cx, 0
    jne cs:FailedWriting
    ;---------------------------------------
    ; check if next buffer must be read
CheckNext:
    mov bl, BytesRead
    cmp bl, max_file_size-6              ; buffer size - 64, max command length - 6
    jl NoNewBufferRequired
    ; move current pointer
    call MovePtr
    ;---------------------------------------
NoNewBufferRequired: 
    mov bl, InputBuffer
    mov bh, 0
    cmp si, bx
    jle BeginRecognising
    jmp Fin
FailedWriting:
    mov ah, 09h
    mov dx, offset FailedWriteMsg
    int 21h
    jmp Fin
Fin:  
    call CloseFiles
    mov ax, 4C00h
    int 21h
END Main