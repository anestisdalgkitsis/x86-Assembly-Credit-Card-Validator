TITLE CCV4 

    ;NOTE:
    ;Some optimization changes have been made acording to intel's manual
    ;http://www.intel.com/content/www/us/en/architecture-and-technology/64-ia-32-architectures-optimization-manual.html
     
CODE SEGMENT
START: 
MOV AX,DATA
MOV DS,AX
 
CALL setgraphicsmode
CALL splashscreen
mainloop:
    CALL menu
    CMP exitbit,1
    JNE mainloop
CALL optimiseScreen 

MOV AX,3 ;Return system on it's previous resolution
INT 10h

MOV AH,4CH
INT 21H
;Files Related Functions

readfile PROC
    PUSH AX
    PUSH CX
    PUSH DX
    PUSH SI
    
    LEA DX,input_file
    MOV AL,0 ;Read Only
    MOV AH,3dh
    INT 21h 
     
    JC disp_load_err ;If carry is 1 then display an error message
    
    MOV BX,AX ;<-- Handler in BX, we need AX for INTs
    

    XOR SI,SI
    MOV cardlenght,0 ;Counts the numbers of each card
    MOV CX,1 ;Read 1 byte every time
    MOV times,0 
    MOV count_characters,0   
    MOV count_numbers,0
    readloop:
        LEA DX,handler ;Set buffer
        MOV AH,3Fh
        INT 21h
        
        CMP AX,0 ;When finish last byte, stop
        JZ exitReadloop
        
        ;read
        MOV DL,handler ;Load what's in buffer in DL
        MOV DH,0
        
        
        CMP DL,0Dh ;If it's CRET, then we finished reading this card
        JE cardloaded 
        
        CMP DL,0Ah
        JE readloop ;If it's an NEWL read the next byte

        CMP DL,30h ;Mark everything below 0 ASCII chararcter as INVALID
        JB invalid_characters_branch
        
        CMP DL,39h ;Mark everything after 9 ASCII chararcter as INVALID
        JA invalid_characters_branch 
        
        INC count_numbers  ;Used to know if line is empty
        
        SUB DL,30h ;Convert ASCII to number               
        MOV cardnum[SI],DL ;STORE number in the card array
        
        INC SI ;Read next byte   
        INC cardlenght ;Increase card lenght counter
        JMP readloop 
        
    invalid_characters_branch:
    INC count_characters 
    INC SI ;Read next byte (because we skipped this action with this branch)         
    INC cardlenght ;Increase card lenght counter (because we skipped this action with this branch)
    JMP readloop
    
    cardloaded:
    DEC cardlenght ;We counted one more number because the counter increased in the end of the loop
    CMP count_characters,0
    JNE invalid_input 
    CMP count_numbers,0
    JE invalid_input 
    MOV count_numbers,0   
    CALL credit_card_type_finder ;Find the type of this card
    CALL LUHNv ;Run LUHN (mod 10) validator algorithm 
    CALL printCards ;Print results  
    
    continue:
    MOV count_characters,0    ;Initialize character counter for next line of .txt
    MOV count_numbers,0       ;Initialize number counter for next line of .txt
    MOV cardlenght,0 ;zero for the next card
    MOV SI,0 ;write cardnum table from beginning                  
    JMP readloop
    
    disp_load_err: ;Display an error message 
    LEA DX,errorfile_msg
    MOV AH,09
    INT 21h
    JMP SKIP1 ;Exit function

    exitReadloop:
    
    CMP times,1       ;if last line goto end of readfile
    JE SKIP1
    
    CMP DX,0AH
    JE  last_line 
    
    invalid_input:
    LEA DX,inv_input
    MOV AH,09H
    INT 21H 
          
    LEA DX,prc_msg
    MOV AH,09H
    INT 21H    
    
    enterloop: ;Waits user to press the RETURN key
        MOV AH,07h
        INT 21h
       
        CMP AL,0Dh
        JNE enterloop
    JMP continue
    
    last_line:
    INC times     ;times used to locate the last line
    JMP cardloaded
    
    
    SKIP1:
    
    POP SI
    POP DX
    POP CX
    POP AX
    RET
    readfile ENDP

; Credit card validation functions

credit_card_type_finder PROC
    PUSH AX
    
    
    ;Mastercard
    
    CMP cardlenght,15 ;0~15 = 16
    JNE noMastercard
     
    CMP cardnum[0],5
    JNE noMastercard
     
    MOV AL,5
    Mastercard2Prefix:
        CMP cardnum[1],AL
        JE isMastercard
        DEC AL
        CMP AL,1 
        JAE Mastercard2Prefix
    noMastercard:
       
    ;VISA    

    CMP cardnum[0],4
    JNE noVISA
         
    CMP cardlenght,15 ;0~15 = 16
    JE isVISA
    
    CMP cardlenght,12 ;0~12 = 13
    JE isVISA     
    
    noVISA:
    
    ;Amex
               
    CMP cardlenght,14 ;0~14 = 15           
    JNE noAmex           
               
    CMP cardnum[0],3
    JNE noAmex
    
    CMP cardnum[1],4
    JE isAmex 
    
    CMP cardnum[1],7
    JE isAmex
    
    noAmex:
    
    ;Diners Club
    
    CMP cardlenght,13 ;0~13 = 14
    JNE noDinersClub 
    
    CMP cardnum[0],3
    JNE noDinersClub
    
    CMP cardnum[1],0
    JNE skip3prefix
    
    MOV AL,0
    DinersClub3prefix:
        CMP cardnum[2],AL
        JE isDinersClub
        
        INC AL
        CMP AL,5
        JBE DinersClub3prefix
        
    skip3prefix:
    
    CMP cardnum[1],6
    JE isDinersClub
    
    CMP cardnum[1],8
    JE isDinersClub
      
    noDinersClub:
    
    ;Discover
    
    CMP cardlenght,15 ;0~15 = 16
    JNE exit_ccv
    
    CMP cardnum[0],6
    JNE exit_ccv 
    
    CMP cardnum[1],0
    JNE exit_ccv
    
    CMP cardnum[2],1
    JNE exit_ccv

    CMP cardnum[3],1
    JNE exit_ccv        
    
    JMP isDiscover
    
    ;Save results
    
    isMastercard:
    MOV cardtype,0
    JMP exit_ccv
    
    isVISA:
    MOV cardtype,1
    JMP exit_ccv
    
    isAMEX:
    MOV cardtype,2
    JMP exit_ccv
    
    isDinersClub:
    MOV cardtype,3
    JMP exit_ccv
    
    isDiscover:
    MOV cardtype,4
    exit_ccv:
    
    POP AX
    RET
    credit_card_type_finder ENDP

LUHNv PROC
    PUSH AX
    PUSH BX
    
    MOV validcard,0 ;Reset variable's value for the new card
    
    CALL reverseArray ;Reverse card numbers to avoid negative counters
    CALL LUHNsum ;Calculates the sum according to LUHN's (mod 10) algorithm
    
    MOV AL,sum
    MOV AH,0
    MOV BL,10
    DIV BL
    CMP AH,0 ;If the last number is NOT 0, then leave card marked as invalid
    JNE invalid
        MOV validcard,1
    invalid:
    
    POP BX
    POP AX
    RET
    LUHNv ENDP

; Tiny tools & Converters

reverseArray PROC ;Perform a serieal reverse of cardnum Array
    PUSH AX
    PUSH BX
    PUSH DX
    PUSH SI
    PUSH DI
    
    MOV AL,cardlenght
    MOV AH,0
    MOV DI,AX
    SAR AX,1
    
    XOR SI,SI
    
    revloop:
        MOV BL,cardnum[SI]   
        MOV BH,cardnum[DI]
        MOV cardnum[SI],BH 
        MOV cardnum[DI],BL
        
        INC SI
        DEC DI 
        
        CMP SI,AX ;loop while SI <= cardlenght
        JBE revloop
    
    POP DI
    POP SI
    POP DX
    POP BX
    POP AX
    RET
    reverseArray ENDP 

LUHNsum PROC
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    
        ;IMPORTANT NOTES:
        ;The cardnum Array is already reversed!
        ;Registers-only architecture to increase speed
    
    XOR CX,CX ;CX is used to keep the 2 sums
              ;CL holds evensum
              ;CH holds oddsum 
    
    MOV DL,cardlenght ;DX holds card's length
    MOV DH,0
    
        ;Find even 's numbers sum & double it according to LUHN's (mod 10) function
    
    XOR AX,AX
    MOV SI,1 ;Start counter from the second number 
    MOV BH,0
    evenloop:
        MOV AL,cardnum[SI] 
        ADD AL,AL ;number+number = numberx2
        CMP AL,9
        JA over10 ;If result is over 10, then add the two digits
        return2:
        ADD CL,AL ;add to existing odd sum
        ADD SI,2
        
        CMP SI,DX
        JBE evenloop 
    
        ;Find odd's numbers sum
        
    XOR SI,SI 
    oddloop:
        ADD CH,cardnum[SI]
        ADD SI,2
        
        CMP SI,DX
        JBE oddloop
    
        ;STORE total sum in memory
         
    ADD CL,CH ;ADD the two sums    
    MOV sum,CL ;STORE in memory for further use
    JMP skipover10 ;Exit function
    
    over10: ;If result is over 10, then add the two digits
        MOV AH,0
        MOV BL,10
        DIV BL
        ADD AL,AH
        JMP return2
        
    skipover10:    
    
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
    LUHNsum ENDP

; Credit card generator functions

card_generator_menu PROC
    PUSH AX
    PUSH DX
    PUSH DI
    PUSH CX
            ; Display title
    
    LEA DX,cgtitle
    MOV AH,09H
    INT 21H 
         
    LEA DX,cgype
    MOV AH,09H
    INT 21H         
    
            ;Type input
            
    check_input:
    MOV AH,08H
    INT 21H
    
    CMP AL,30h
    JB check_input
    
    CMP AL,34h
    JA check_input    
    
    MOV DL,AL
    MOV AH,02H
    INT 21H    
    
    SUB AL,30H
    
    MOV cardtype,AL
    MOV AH,0
    MOV DI,AX
    MOV AL,card_lengths[DI] ;store valid cardtype                      
    MOV cardlenght,AL
    
    LEA DX,cg_number_of_cards
    MOV AH,09H
    INT 21H
             
    num_check1:
    MOV AH,08H
    INT 21H
    
    CMP AL,30H
    JB num_check1
    
    CMP AL,39H
    JA num_check1
    
    MOV DL,AL
    MOV AH,02H
    INT 21H 
    
    SUB AL,30H
    
    MOV AH,0
    MOV CL,100
    MUL CL 
    
    MOV ekatontada,AX
    
    num_check2:
    
    MOV AH,08H
    INT 21H
    
    CMP AL,30H
    JB num_check2
    
    CMP AL,39H
    JA num_check2
    
    MOV DL,AL
    MOV AH,02H
    INT 21H
    
    SUB AL,30H
    
    MOV AH,0
    MOV CL,10
    MUL CL
    
    MOV dekada,AL
    
    num_check3:
    
    MOV AH,08H
    INT 21H
    
    CMP AL,30H
    JB num_check3
    
    CMP AL,39H
    JA num_check3
    
    MOV DL,AL
    MOV AH,02H
    INT 21H
    
    SUB AL,30H
    
    MOV monada,AL
    
    MOV CL,dekada
    MOV CH,0
    ADD ekatontada,CX
    MOV CL,monada
    MOV CH,0
    ADD ekatontada,CX
    
    MOV DX,ekatontada
    
        
    PUSH DX ;Keep DX values untuched of INT 21h
    LEA DX,newline
    MOV AH,09H
    INT 21H
    POP DX ;Restore DX value
            
    CMP DX,0
    JE skip_genloop
    
    XOR DI,DI
    
    forallthecards: ;For all the cards
        MOV validcard,0 ;Set the new one as invalid     
        genloop:
            CALL cards_generator ;Generates a random card, according to the type requested
            CALL LUHNv ;LUHN check's if this number is valid. If it is sets this card as VALID
            CMP validcard,1 ;If it's not valid
            JNE genloop ;Generate a new one 
        CALL printCards ;Print result
        INC DI ;Go for the next card
        CMP DI,DX ;If not finished
        JB forallthecards ;Do one more card again
        
        skip_genloop:
    POP CX     
    POP DI
    POP DX
    POP AX
    RET
    card_generator_menu ENDP

cards_generator PROC
    PUSH AX
    PUSH BX
    PUSH SI
    
    MOV AL,cardlenght ;LOAD requested card's lenght according to its type
    MOV AH,0
    
    XOR SI,SI
    
        ;This sector presets numbers to match the type requested
         
    CMP cardtype,0
    JE isMastercard1
    
    CMP cardtype,1
    JE isVISA1         
    
    CMP cardtype,2
    JE isAmex1
    
    CMP cardtype,3
    JE isDinersClub1    

    CMP cardtype,4
    JE isDiscover1
    
    return1:
    
        ;This sector fills all the other empty slots with random numbers
        
        ;IMPORTANT NOTE:
        ;SI (counter) has been modified in the previous sector
         
    cardgenloop:
        CALL Pseudonoise_Number_Generator ;Give me a random number
        MOV BL,random_num
        MOV cardnum[SI],BL ;STORE random number 
        INC SI ;Go to the next one
        CMP SI,AX
        JB cardgenloop
    JMP skip3 ;Exit
    
        ;Set preset numbers to match the type requested    
    
    isMastercard1:
        MOV cardnum[0],5
        MOV cardnum[1],5
        MOV SI,2
        JMP return1
        
    isVISA1:
        MOV cardnum[0],4
        MOV SI,1
        JMP return1
    
    isAmex1:
        MOV cardnum[0],3
        MOV cardnum[1],7
        MOV SI,2
        JMP return1
        
    isDinersClub1:
        MOV cardnum[0],3
        MOV cardnum[1],8
        MOV SI,2
        JMP return1
            
    isDiscover1:
        MOV cardnum[0],6
        MOV cardnum[1],0
        MOV cardnum[2],1
        MOV cardnum[3],1
        MOV SI,4
        JMP return1 
              
    skip3:
    
    POP SI
    POP BX
    POP AX
    RET
    cards_generator ENDP

Pseudonoise_Number_Generator PROC
    PUSH AX
    PUSH DX
    PUSH CX
    
    pseudoLoop:
        MOV AH,0 ;Read ticks.
        INT 1Ah  ;Time of day interrupt.
                 ;To DX low word
                 ;To CX high word
        AND DX,1111b
        CMP DL,9
        JA pseudoLoop
    MOV random_num, DL
    
    POP CX
    POP DX
    POP AX
    RET
    Pseudonoise_Number_Generator ENDP
 
; Graphics related functions  

setgraphicsmode PROC ;Set system's resolution @ 320x200 ,8Bit color depth
    PUSH AX
    
    XOR AX,AX; Intialize AX REGISTER
    
    MOV AL,13h
    INT 10h
    
    POP AX
    RET
    setgraphicsmode ENDP

splashscreen PROC ;Prints the start up graphical environment
    PUSH AX
    PUSH BX
    PUSH CX
    
    MOV color,9 ;Draw with blue color 
    
        ;Upper box
    
    XOR AX,AX
    XOR BX,BX
    MOV CX,12800
    CALL drawbox
    
        ;Lower box
        
    MOV AX,160
    XOR BX,BX
    MOV CX,12800
    CALL drawbox
    
    CALL ASCIIart ;Draw the "CCV_4" title with ASCII
    
    enterloop1: ;Wait user to press the RETURN key
        MOV AH,07h
        INT 21h
        CMP AL,0Dh
        JNE enterloop1
        
    POP CX
    POP BX
    POP AX
    RET
    splashscreen ENDP

menu PROC ;Prints the menu in screen
    PUSH AX
    PUSH DX
    
    MOV exitbit,0 ;We set it on when
    
        ;Menu made with ASCII characters
    
            ;Menu Header
    
    MOV AH,02
    MOV DH,6 ;ROW
    MOV DL,9 ;COLUMN
    INT 10h
    ;Source: en.wikipaidia.org/wiki/INT_10H
        
    LEA DX,MA0
    MOV AH,09
    INT 21h

    MOV AH,02
    MOV DH,7 ;ROW
    MOV DL,9 ;COLUMN
    INT 10h
    ;Source: en.wikipaidia.org/wiki/INT_10H
        
    LEA DX,MA1
    MOV AH,09
    INT 21h

    MOV AH,02
    MOV DH,8 ;ROW
    MOV DL,9 ;COLUMN
    INT 10h
    ;Source: en.wikipaidia.org/wiki/INT_10H
    
    
            ;Menu Options
        
    LEA DX,MA2
    MOV AH,09
    INT 21h    
    
    MOV AH,02
    MOV DH,9 ;ROW
    MOV DL,9 ;COLUMN
    INT 10h
    ;Source: en.wikipaidia.org/wiki/INT_10H
        
    LEA DX,MA3
    MOV AH,09
    INT 21h        

    MOV AH,02
    MOV DH,10 ;ROW
    MOV DL,9 ;COLUMN
    INT 10h
    ;Source: en.wikipaidia.org/wiki/INT_10H
        
    LEA DX,MA4
    MOV AH,09
    INT 21h

    MOV AH,02
    MOV DH,11 ;ROW
    MOV DL,9 ;COLUMN
    INT 10h
    ;Source: en.wikipaidia.org/wiki/INT_10H
        
    LEA DX,MA5
    MOV AH,09
    INT 21h    

    MOV AH,02
    MOV DH,12 ;ROW
    MOV DL,9 ;COLUMN
    INT 10h
    ;Source: en.wikipaidia.org/wiki/INT_10H
        
    LEA DX,MA6
    MOV AH,09
    INT 21h
        
            ;Last Row
    
    MOV AH,02
    MOV DH,13 ;ROW
    MOV DL,9 ;COLUMN
    INT 10h
    ;Source: en.wikipaidia.org/wiki/INT_10H
        
    LEA DX,MA7
    MOV AH,09
    INT 21h

            ;Shadow
            
    MOV AH,02
    MOV DH,14 ;ROW
    MOV DL,9 ;COLUMN
    INT 10h
    ;Source: en.wikipaidia.org/wiki/INT_10H
        
    LEA DX,MA8
    MOV AH,09
    INT 21h    
            ;USER OPTIONS
    
    menuloop:
        MOV AH,07h ;Asynchronous input enabler 
        INT 21h
        CMP AL,31h ;DISCARD options below and equal "0" ASCII
        JB menuloop
        CMP AL,34h ;DISCARD options after "4" ASCII
        JA menuloop    

    CMP AL,31h ;If user pressed 1 -- [Load File] then
    JNE skipreadfile
    CALL optimiseScreen ;Fill screen with black and reset cursor
    CALL readfile 
    skipreadfile:
    
    CMP AL,32h ;If user pressed 2 -- [Generate Cards] then
    JNE skipcardgenerator
    CALL optimiseScreen ;Fill screen with black and reset cursor
    CALL card_generator_menu 
    skipcardgenerator:
    
    CMP AL,33h ;If user pressed 3 -- [Exit] then
    JNE skipexit
    MOV exitbit,1 ;Inform program that user wants to terminate the process 
    skipexit:    

    CMP AL,34h ;If user pressed 4 -- [About] then
    JNE skipabout
    CALL optimiseScreen ;Fill screen with black and reset cursor
    CALL splashscreen 
    skipabout:
                
    POP DX
    POP AX
    RET
    menu ENDP 
    
optimiseScreen PROC ;Black screen & reset cursor position
    PUSH AX
    PUSH BX
    PUSH CX
    PUSH DX
    
    ;Fill black        
    XOR AX,AX
    XOR BX,BX
    MOV CX,64000
    MOV color,0h
    CALL drawbox
    
    ;Return cursor to start of screen
    MOV AH,02
    XOR DX,DX ;Before optimise was: MOV DH,0 (ROW),MOV DL,0 (COLUMN)
    INT 10h
    ;Source: en.wikipaidia.org/wiki/INT_10H
    
    POP DX
    POP CX
    POP BX
    POP AX
    RET
    optimiseScreen ENDP    

drawbox PROC; X=BX,Y=AX
    PUSH AX
    PUSH BX
    PUSH CX

    MOV DX,320
    MUL DX 
    ADD AX,BX
    MOV SI,AX
    MOV BX,0A000h
    MOV ES,BX
    
    MOV DX,color ;Load color in a register for faster operation
    drawline:
        MOV ES:[SI],DX
        INC SI
        LOOP drawline
    
    POP CX
    POP BX
    POP AX
    RET
    drawbox ENDP

ASCIIart PROC ;Draws the "CCV_4" title with ASCII
    PUSH AX
    PUSH BX
    PUSH DX
    
    LEA DX,AA0
    MOV AH,09
    INT 21h
        
    LEA DX,AA1
    MOV AH,09
    INT 21h
        
    LEA DX,AA2
    MOV AH,09
    INT 21h 
       
    LEA DX,AA3
    MOV AH,09
    INT 21h  
      
    LEA DX,AA4
    MOV AH,09
    INT 21h   
     
    LEA DX,AA5
    MOV AH,09
    INT 21h  
      
    LEA DX,AA6
    MOV AH,09
    INT 21h    

    LEA DX,AA7
    MOV AH,09
    INT 21h
    
    LEA DX,AA8
    MOV AH,09
    INT 21h
    
    LEA DX,AA9
    MOV AH,09
    INT 21h
    
    LEA DX,AA10
    MOV AH,09
    INT 21h
    
    LEA DX,AA11
    MOV AH,09
    INT 21h
              
    POP DX
    POP BX
    POP AX
    RET
    ASCIIart ENDP

; Output functions

printCards PROC
    PUSH AX
    PUSH DX
   
    CMP validcard,0
    JE invalid2
    
    CMP validcard,1
    JNE SKIP2
        
        CALL printcard
        
        LEA DX,valid_msg
        MOV AH,09
        INT 21h
                         
        CMP cardtype,0
        JNE noMastercard2
            LEA DX,Mastercard_msg
            MOV AH,09
            INT 21h                      
            JMP SKIP2       
        noMastercard2:

        CMP cardtype,1
        JNE noVISA2
            LEA DX,VISA_msg
            MOV AH,09
            INT 21h            
            JMP SKIP2       
        noVISA2:
        
        CMP cardtype,2
        JNE noAmex2
            LEA DX,Amex_msg
            MOV AH,09
            INT 21h          
            JMP SKIP2       
        noAmex2:
        
        CMP cardtype,3
        JNE noDinersClub2
            LEA DX,DinersClub_msg
            MOV AH,09
            INT 21h
            JMP SKIP2       
        noDinersClub2:
        
        CMP cardtype,4
        JNE noDiscover2
            LEA DX,Discover_msg
            MOV AH,09
            INT 21h
            JMP SKIP2       
        noDiscover2:        
        JMP SKIP2
         
    invalid2:
    
    CALL printcard
    
    LEA DX,inv_msg
    MOV AH,09
    INT 21h
    
    SKIP2:
    
    LEA DX,prc_msg
    MOV AH,09
    INT 21h    
    
    enterloop0:
        MOV AH,07h
        INT 21h
        CMP AL,0Dh
        JNE enterloop0
    
    POP DX
    POP AX
    RET
    printCards ENDP

printcard PROC
    PUSH AX
    PUSH BX
    PUSH DX
    PUSH SI
    
        ;IMPORTANT NOTE:
        ;remember! The card is reversed!
        
    CALL reverseArray ;Return card to it's actual number  
    
    MOV BL,cardlenght
    MOV BH,0
    
    LEA DX,newline
    MOV AH,09h
    INT 21h
    
    XOR SI,SI
    cardloop:        
        MOV DL,cardnum[SI]
        ADD DL,30h
        MOV AH,02h
        INT 21h
        
        INC SI
        CMP SI,BX
        JBE cardloop
    
    POP SI
    POP DX
    POP BX
    POP AX
    RET
    printcard ENDP
       
CODE ENDS 
          
DATA SEGMENT
;File streams & Buffers
input_file db "cards.txt",0
handler db ?     
;Variables
ekatontada dw 0
dekada db 0
monada db 0 
count_characters db 0 
count_numbers db 0
cardlenght db 0
cardtype db 255 ;255=Error,0=Mastercard,1=VISA,2=Amex,3=DinersClub,4=Discover
validcard db 0 ;255=Error,0=invalid,1=Valid
sum db 0
color dd 0
exitbit db 0 
times db 0 
random_num db 0
;Arrays
cardnum db 255 dup(0)
card_lengths db 15,15,14,13,15 ;0=Mastercard[0~15=16],1=VISA[0~15=16],2=Amex[0~14=15],3=DinersClub[0~12=13],4=Discover[0~15=16] 
;Strings
errorfile_msg db 07h,10,13," /!\ ERROR while opening file",10,13,"$"
valid_msg db " VALID Type:","$" 
inv_input db 10,13," INVALID INPUT /!\",10,13,"$"
inv_msg db " INVALID Type /!\",10,13,"$"
Mastercard_msg db "Mastercard",10,13,"$" 
VISA_msg db "VISA",10,13,"$"
Amex_msg db "Amex",10,13,"$"
DinersClub_msg db "Diners Club",10,13,"$"
Discover_msg db "Discover",10,13,"$"
newline dw 10,13,"$"
prc_msg db 20h,0C0h,"Press RETURN to load/generate card",10,13,"$"
cgtitle db 10,13," [i] Credit Card Generator <Beta v2>",10,13,20h,20h,0C0h,"Warning! Very slow process",10,13,"$"
cgype db 10,13," [>] Type of card to generate:",10,13,"  |- 0 for Mastercard",10,13,"  |- 1 for VISA",10,13,"  |- 2 for Amex",10,13,"  |- 3 for Diners Club",10,13,"  |- 4 for Discover ", 10,13," [Type selected]: ","$"
cg_number_of_cards db 10,13,10,13," [>] Number of cards to generate:",10,13," [Numbers Selected]: ","$"
;ASCII ART
AA0 db 10,13,10,13,10,13,10,13,10,13,10,13,20h,20h,0DBh,0DBh,0DBh,0DBh,0DBh,0DBh,0BBh,20h,0DBh,0DBh,0DBh,0DBh,0DBh,0DBh,0BBh,0DBh,0DBh,0BBh,20h,20h,20h,0DBh,0DBh,0BBh,20h,20h,0DBh,0DBh,0BBh,20h,20h,0DBh,0DBh,0BBh,10,13,"$"
AA1 db 20h,0DBh,0DBh,0C9h,0CDh,0CDh,0CDh,0CDh,0BCh,0DBh,0DBh,0C9h,0CDh,0CDh,0CDh,0CDh,0BCh,0DBh,0DBh,0BAh,20h,20h,20h,0DBh,0DBh,0BAh,20h,20h,0DBh,0DBh,0BAh,20h,20h,0DBh,0DBh,0BAh,10,13,"$"
AA2 db 20h,0DBh,0DBh,0BAh,20h,20h,20h,20h,20h,0DBh,0DBh,0BAh,20h,20h,20h,20h,20h,0DBh,0DBh,0BAh,20h,20h,20h,0DBh,0DBh,0BAh,20h,20h,0DBh,0DBh,0DBh,0DBh,0DBh,0DBh,0DBh,0BAh,10,13,"$"
AA3 db 20h,0DBh,0DBh,0BAh,20h,20h,20h,20h,20h,0DBh,0DBh,0BAh,20h,20h,20h,20h,20h,0C8h,0DBh,0DBh,0BBh,20h,0DBh,0DBh,0C9h,0BCh,20h,20h,0C8h,0CDh,0CDh,0CDh,0CDh,0DBh,0DBh,0BAh,10,13,"$"
AA4 db 20h,0C8h,0DBh,0DBh,0DBh,0DBh,0DBh,0DBh,0BBh,20h,0C8h,0DBh,0DBh,0DBh,0DBh,0DBh,0DBh,0BBh,0C8h,0DBh,0DBh,0DBh,0DBh,0C9h,0BCh,0DBh,0DBh,0DBh,0DBh,0DBh,0DBh,0DBh,0BBh,0DBh,0DBh,0BAh,10,13,"$"
AA5 db 20h,20h,0C8h,0CDh,0CDh,0CDh,0CDh,0CDh,0BCh,20h,20h,0C8h,0CDh,0CDh,0CDh,0CDh,0CDh,0BCh,20h,0C8h,0CDh,0CDh,0CDh,0BCh,20h,0C8h,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0BCh,0C8h,0CDh,0BCh,10,13,"$"
AA6 db 10,13," [i] Credit Card Validator <Version 4>",10,13,"$"
AA7 db "  |   Anestis Dalgkitsis, @586",10,13,"$"
AA8 db "  |   Giwrgos Kalampokis, @594",10,13,"$"
AA9 db "  |   Xristos Palamiwtis, @648",10,13,"$"
AA10 db "  |   Xristos Tolis     , @632",10,13,"$"
AA11 db " [>]-<Press RETURN to continue>",10,13,"$"
;Menu ASCII strings
MA0 db 0C9h,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0BBh,"$"
MA1 db 0BAh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,"[","M","E","N","U","]",0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0BAh,0B1h,"$"
MA2 db 0CCh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0B9h,0B1h,"$"
MA3 db 0BAh,20h,"1",20h,"-",20h,"L","o","a","d",20h,"F","i","l","e",20h,20h,20h,20h,20h,20h,0BAh,0B1h,"$"
MA4 db 0BAh,20h,"2",20h,"-",20h,"G","e","n","e","r","a","t","e",20h,"C","a","r","d","s",20h,0BAh,0B1h,"$"
MA5 db 0BAh,20h,"3",20h,"-",20h,"E","x","i","t",20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,0BAh,0B1h,"$"
MA6 db 0BAh,20h,"4",20h,"-",20h,"A","b","o","u","t",20h,20h,20h,20h,20h,20h,20h,20h,20h,20h,0BAh,0B1h,"$"
MA7 db 0C8h,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0CDh,0BCh,0B1h,"$"
MA8 db 20h,0B1h,0B1h,0B1h,0B1h,0B1h,0B1h,0B1h,0B1h,0B1h,0B1h,0B1h,0B1h,0B1h,0B1h,0B1h,0B1h,0B1h,0B1h,0B1h,0B1h,0B1h,0B1h,"$" 
DATA ENDS

STACK SEGMENT STACK
db 256 dup(0)
STACK ENDS

END START                     