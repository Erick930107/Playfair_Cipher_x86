INCLUDE Irvine32.inc

.data
    ; Playfair key matrix (5x5)
    keyMatrix BYTE "MONARCHYBDEFGIKLPQSTUVWXZ"
    
    ; Input/Output messages
    promptInput BYTE "Please input the plaintext: ", 0
    msgModified BYTE "Modified plaintext: ", 0
    msgCipher BYTE "The ciphertext is: ", 0
    
    ; Input buffer and processed text
    inputBuffer BYTE 256 DUP(?)
    processedText BYTE 256 DUP(?)
    finalText BYTE 512 DUP(?)  
    cipherText BYTE 512 DUP(?)
    
    ; Temporary variables
    pair1 BYTE ?
    pair2 BYTE ?
    row1 BYTE ?
    col1 BYTE ?
    row2 BYTE ?
    col2 BYTE ?
    
    ; Constants
    SPACE BYTE " ", 0
    NEWLINE BYTE 13, 10, 0

.code
main PROC
    ; Get plaintext input
    mov edx, OFFSET promptInput
    call WriteString
    mov edx, OFFSET inputBuffer
    mov ecx, 256
    call ReadString
    
    ; Process plaintext (remove spaces, convert to uppercase, handle pairs)
    call ProcessPlaintext
    
    ; Display modified plaintext
    mov edx, OFFSET msgModified
    call WriteString
    call DisplayPairs
    call Crlf
    
    ; Encrypt using Playfair cipher
    call Playfair
    
    ; Display ciphertext
    mov edx, OFFSET msgCipher
    call WriteString
    call DisplayCipher
    call Crlf
    
    exit
main ENDP

ProcessPlaintext PROC
    pushad
    
    mov esi, OFFSET inputBuffer
    mov edi, OFFSET processedText
    
ProcessLoop:
    mov al, [esi]
    cmp al, 0
    je EndProcess
    
    ; Check if it's a letter
    cmp al, 'a'
    jb CheckUppercase
    cmp al, 'z'
    ja NotLetter
    ; Convert lowercase to uppercase
    sub al, 32
    jmp IsLetter
    
CheckUppercase:
    cmp al, 'A'
    jb NotLetter
    cmp al, 'Z'
    ja NotLetter
    jmp IsLetter  
    
IsLetter:
    ; Handle I/J equivalence (treat J as I)
    cmp al, 'J'
    jne StoreChar
    mov al, 'I'
    
StoreChar:
    mov [edi], al
    inc edi
    
NotLetter:
    inc esi
    jmp ProcessLoop
    
EndProcess:
    mov BYTE PTR [edi], 0  ; Null terminate
    
    ; Handle pairs and repeated letters
    call HandlePairs
    
    popad
    ret
ProcessPlaintext ENDP

HandlePairs PROC
    pushad
    
    mov esi, OFFSET processedText
    mov edi, OFFSET finalText
    
PairProcessLoop:
    mov al, [esi]
    cmp al, 0
    je CheckOddLength
    
    ; Get next character
    mov bl, [esi+1]
    cmp bl, 0
    je SingleChar
    
    ; Check if current pair has same letters
    cmp al, bl
    jne DifferentLetters
    
    ; Same letters - insert X between them
    mov [edi], al        ; Store first letter
    inc edi
    mov BYTE PTR [edi], 'X'  ; Insert X
    inc edi
    inc esi              ; Move to next character (don't skip the repeated one)
    jmp PairProcessLoop
    
DifferentLetters:
    ; Different letters - store both
    mov [edi], al
    inc edi
    mov [edi], bl
    inc edi
    add esi, 2           ; Skip both characters
    jmp PairProcessLoop
    
SingleChar:
    ; Single character left - store it
    mov [edi], al
    inc edi
    inc esi
    jmp PairProcessLoop
    
CheckOddLength:
    ; Check if final length is odd
    mov esi, OFFSET finalText
    mov ecx, 0
    
CountLoop:
    mov al, [esi]
    cmp al, 0
    je CountDone
    inc ecx
    inc esi
    jmp CountLoop
    
CountDone:
    ; If odd length, add 'X' at the end
    test ecx, 1
    jz PairsDone
    
    mov esi, OFFSET finalText
    add esi, ecx
    mov BYTE PTR [esi], 'X'
    inc esi
    mov BYTE PTR [esi], 0
    
PairsDone:
    popad
    ret
HandlePairs ENDP

Playfair PROC
    pushad
    
    mov esi, OFFSET finalText
    mov edi, OFFSET cipherText
    
EncryptLoop:
    mov al, [esi]
    cmp al, 0
    je EncryptDone
    
    mov bl, [esi+1]
    cmp bl, 0
    je EncryptDone
    
    ; Store current pair
    mov pair1, al
    mov pair2, bl
    
    ; Find positions in key matrix
    call FindPosition
    
    ; Apply Playfair rules
    call ApplyPlayfairRules
    
    ; Store encrypted pair
    mov al, pair1
    mov bl, pair2
    mov [edi], al
    inc edi
    mov [edi], bl
    inc edi
    
    add esi, 2
    jmp EncryptLoop
    
EncryptDone:
    mov BYTE PTR [edi], 0
    
    popad
    ret
Playfair ENDP

FindPosition PROC
    pushad
    
    ; Find position of first character
    mov al, pair1
    call GetMatrixPosition
    mov row1, bl
    mov col1, bh
    
    ; Find position of second character
    mov al, pair2
    call GetMatrixPosition
    mov row2, bl
    mov col2, bh
    
    popad
    ret
FindPosition ENDP

GetMatrixPosition PROC
    push eax
    push ecx
    push esi
    
    mov esi, OFFSET keyMatrix
    mov ecx, 25
    
SearchMatrix:
    cmp al, [esi]
    je FoundChar
    inc esi
    dec ecx
    jnz SearchMatrix
    
FoundChar:
    ; Calculate position
    mov eax, 25
    sub eax, ecx
    ; EAX now contains index (0-24)
    
    ; Calculate row = index / 5
    mov bl, 5
    div bl
    mov bl, al  ; row in BL
    mov bh, ah  ; column in BH
    
    pop esi
    pop ecx
    pop eax
    ret
GetMatrixPosition ENDP

ApplyPlayfairRules PROC
    pushad
    
    mov al, row1
    mov bl, row2
    cmp al, bl
    je SameRow
    
    mov al, col1
    mov bl, col2
    cmp al, bl
    je SameColumn
    
    ; Different row and column - rectangle rule
    jmp Rectangle
    
SameRow:
    ; Same row - move right with wrapping
    mov al, row1
    mov bl, col1
    inc bl
    cmp bl, 5
    jne NoWrap1
    mov bl, 0
NoWrap1:
    call GetCharFromMatrix
    mov pair1, al
    
    mov al, row2
    mov bl, col2
    inc bl
    cmp bl, 5
    jne NoWrap2
    mov bl, 0
NoWrap2:
    call GetCharFromMatrix
    mov pair2, al
    jmp RulesDone
    
SameColumn:
    ; Same column - move down with wrapping
    mov al, row1
    mov bl, col1
    inc al
    cmp al, 5
    jne NoWrap3
    mov al, 0
NoWrap3:
    call GetCharFromMatrix
    mov pair1, al
    
    mov al, row2
    mov bl, col2
    inc al
    cmp al, 5
    jne NoWrap4
    mov al, 0
NoWrap4:
    call GetCharFromMatrix
    mov pair2, al
    jmp RulesDone
    
Rectangle:
    ; Rectangle rule - swap columns
    mov al, row1
    mov bl, col2
    call GetCharFromMatrix
    mov pair1, al
    
    mov al, row2
    mov bl, col1
    call GetCharFromMatrix
    mov pair2, al
    
RulesDone:
    popad
    ret
ApplyPlayfairRules ENDP

GetCharFromMatrix PROC
    push ebx
    push esi
    
    ; Calculate index = row * 5 + column
    mov ah, 0
    mov bh, 0
    mov cl, 5
    mul cl
    add al, bl
    
    mov esi, OFFSET keyMatrix
    add esi, eax
    mov al, [esi]
    
    pop esi
    pop ebx
    ret
GetCharFromMatrix ENDP

DisplayPairs PROC
    pushad
    
    mov esi, OFFSET finalText
    
PairDisplayLoop:
    mov al, [esi]
    cmp al, 0
    je PairDisplayDone
    
    ; Display first character
    call WriteChar
    inc esi
    
    mov al, [esi]
    cmp al, 0
    je PairDisplayDone
    
    ; Display second character
    call WriteChar
    inc esi
    
    ; Add space between pairs
    mov edx, OFFSET SPACE
    call WriteString
    
    jmp PairDisplayLoop
    
PairDisplayDone:
    popad
    ret
DisplayPairs ENDP

DisplayCipher PROC
    pushad
    
    mov esi, OFFSET cipherText
    
CipherDisplayLoop:
    mov al, [esi]
    cmp al, 0
    je CipherDisplayDone
    
    ; Display first character
    call WriteChar
    inc esi
    
    mov al, [esi]
    cmp al, 0
    je CipherDisplayDone
    
    ; Display second character
    call WriteChar
    inc esi
    
    ; Add space between pairs
    mov edx, OFFSET SPACE
    call WriteString
    
    jmp CipherDisplayLoop
    
CipherDisplayDone:
    popad
    ret
DisplayCipher ENDP

END main