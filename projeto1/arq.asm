.386

.model flat, stdcall
option casemap :none
include \masm32\include\windows.inc
include \masm32\include\kernel32.inc
include \masm32\include\masm32.inc
include \masm32\include\msvcrt.inc
include \masm32\macros\macros.asm
includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\masm32.lib
includelib \masm32\lib\msvcrt.lib

.data
entrada db 10 dup(?) ; string onde a entrada eh armazenada
read_count dw 0      ; usada em readConsole
write_count dw 0 ;usada em writeConsole
strResultado db 4 dup(?)


output_ler_n_notas db 0ah, " Quantas notas serao inseridas? (2-10)", 0ah, 0h 
output_ler_nota db 0ah, " Digite uma nota: ", 0ah, 0h 
output_mostrar_media db 0ah, " Media:", 0ah, 0h
output_pergunta_sn db 0ah, "Deseja realizar a operacao novamente? (s/n)? ", 0ah, 0h
output_aprovado db " O aluno foi aprovado!", 0ah, 0h
output_reprovado db " O aluno foi reprovado!", 0ah, 0h
output_final db 0ah,0ah, " O aluno foi para a final e precisa tirar no minimo: ", 0ah, 0h
output_nota_n_numerico db "Digite um caracter numérico.", 0ah, 0h


;; Array de Notas
strNumNotas db 10 dup(?)
numNotas dd ?            
arrayNotas real8 10 dup(0.0) 

;; media
f_media real8 ?
f_media_final real8 ?
str_media db 10 dup(?)
str_media_final db 10 dup(?)

;; constantes
f_zero real8 0.0
f_aprovado real8 7.0
f_reprovado real8 4.0
f_cinquenta real8 50.0
f_peso_media real8 6.0
f_peso_final real8 4.0


;; entrada
entrada_nota db 10 dup(?)
f_nota real8 ?
entrada_char db 3 dup(?)
char_s db "s"


.code
start:                     
  _pegaNumNotas:
  mov numNotas, 0
  mov read_count, 0
  mov write_count, 0

  fld f_zero
  fstp f_media
  
  mov eax, 0
  mov ebx, 0 ;zera ebx
  
  ;; printa input de quantidade de notas
  push STD_OUTPUT_HANDLE
  call GetStdHandle
  invoke WriteConsole, eax, addr output_ler_n_notas, sizeof output_ler_n_notas, addr write_count, NULL 

  ;; recebe entrada da quantidade de notas
  push STD_INPUT_HANDLE
  call GetStdHandle
  invoke ReadConsole, eax, addr strNumNotas, sizeof strNumNotas, addr read_count, NULL ;recebe numero de notas 

  ;correcao do int recebido no terminal:
  mov esi, offset strNumNotas ; Armazenar apontador da string em esi
  proximo:
    mov al, [esi] ; Mover caracter atual para al
    inc esi ; Apontar para o proximo caracter
    cmp al, 48 ; Verificar se menor que ASCII 48 - FINALIZAR
    jl terminar
    cmp al, 58 ; Verificar se menor que ASCII 58 - CONTINUAR
    jl proximo
  terminar:
    dec esi ; Apontar para caracter anterior
    xor al, al ; 0 ou NULL
    mov [esi], al ; Inserir NULL logo apos o termino do numero
    ;fim do codigo de correcao.

  mov eax, 0
  invoke atodw, addr strNumNotas ;armazena valor convertido em ax

  mov numNotas, eax ;pega numero de notas
  
  ;; ler a quantidade n de notas
  _lerNotas:
    push STD_OUTPUT_HANDLE
    call GetStdHandle
    invoke WriteConsole, eax, addr output_ler_nota, sizeof output_ler_nota, addr write_count, NULL 

    ;; recebe cada nota
    push STD_INPUT_HANDLE
    call GetStdHandle
    invoke ReadConsole, eax, addr entrada_nota, sizeof entrada_nota, addr read_count, NULL 

    ;; converte entrada str para float
    push ebx
    invoke StrToFloat, addr entrada_nota, addr f_nota 
    pop ebx

    fld f_nota 
    fstp arrayNotas[ebx * 8]

    add ebx, 1
    cmp ebx, numNotas
    jl _lerNotas

  _calculaMedia:
    ;; calcular a media
    mov ebx, 0

    _carrega:
    ;; loop para dar load nos valores do array para a stack da FPU
      fld arrayNotas[ebx * 8]
      add ebx, 1
      cmp ebx, numNotas
      jl _carrega

    sub numNotas, 1 ; necessario pq nao iremos pegar o topo da pilha, pois a soma sempre vai ficar armazenada no topo
    mov ebx, 0
    ;; soma todas as notas
    _somarNotas:
      fadd
      add ebx, 1
      cmp ebx, numNotas
      jl _somarNotas
    
    add numNotas, 1
    fild numNotas ;; carrega o valor de notas para o stack de floats
    fdiv
    fstp f_media

    push ebx
    invoke FloatToStr, f_media, addr str_media ; converte o valor da media para string para printar
    pop ebx


  push STD_OUTPUT_HANDLE 
  call GetStdHandle
  invoke WriteConsole, eax, addr output_mostrar_media, sizeof output_mostrar_media, addr write_count, NULL 

  push STD_OUTPUT_HANDLE 
  call GetStdHandle
  invoke WriteConsole, eax, addr str_media, sizeof str_media, addr write_count, NULL 

  ;; como comparar dois floats https://gist.github.com/nikAizuddin/0e307cac142792dcdeba at example 11
  mov eax, 0 ; reseta eax
  finit ; reseta stack da FPU
  fld f_media ; carrega media no stack
  fld f_aprovado ; carrega constate de aprovado no stack

  fcom ; compara o f_media com o f_aprovado
  fstsw ax ; o fcom poem os resultados no EFLAGS que n ficam nos registradores da CPU, precisando mover para o ax

  and eax, 0100011100000000B  ;; (CF && ZF)
   cmp    eax, 0000000000000000B ;is st0 > source ?
    je     _final
    cmp    eax, 0000000100000000B ;is st0 < source ?
    je     _aprovado
    cmp    eax, 0100000000000000B ;is st0 = source ?
    je     _aprovado

  _aprovado:
    push STD_OUTPUT_HANDLE ;; printa inicio da mensagem
    call GetStdHandle
    invoke WriteConsole, eax, addr output_aprovado, sizeof output_aprovado, addr write_count, NULL ;printa frase aprovado
    
    jmp _perguntaSN

  _final:

    _mediaFinal:
      finit ;; resetar fpu stack
      mov eax, 0 ;; reseta eax

      fld f_media
      fld f_reprovado

      fcom 
      fstsw ax

      and eax, 0100011100000000B  ;; (CF && ZF)
      cmp eax, 0000000000000000B ;is f_reprovado > f_media ?
      je _reprovado

      _calculoMediaFinal:
        finit
        fld f_cinquenta
        fld f_media
        fld f_peso_media
        fmul
        fsub
        fld f_peso_final
        fdiv

        fstp f_media_final

        push ebx
        invoke FloatToStr, f_media_final, addr str_media_final
        pop ebx

        push STD_OUTPUT_HANDLE ;; printa inicio da mensagem
        call GetStdHandle
        invoke WriteConsole, eax, addr output_final, sizeof output_final, addr write_count, NULL ;printa frase foi para final

        push STD_OUTPUT_HANDLE ;; printa inicio da mensagem
        call GetStdHandle
        invoke WriteConsole, eax, addr str_media_final, sizeof str_media_final, addr write_count, NULL ;printa frase foi para final
        jmp _perguntaSN

    _reprovado:
      push STD_OUTPUT_HANDLE ;; printa inicio da mensagem
      call GetStdHandle
      invoke WriteConsole, eax, addr output_reprovado, sizeof output_reprovado, addr write_count, NULL ;printa frase foi para final
      jmp _perguntaSN

    _perguntaSN:
      push STD_OUTPUT_HANDLE ;; printa inicio da mensagem
      call GetStdHandle
      invoke WriteConsole, eax, addr output_pergunta_sn, sizeof output_pergunta_sn, addr write_count, NULL ;printa frase foi para final

      push STD_INPUT_HANDLE
      call GetStdHandle
      invoke ReadConsole, eax, addr entrada_char, sizeof entrada_char, addr read_count, NULL ;recebe numero de notas 

      mov al, entrada_char
      cmp al, char_s
      je start

  _endprog:
      invoke ExitProcess, 0
end start
