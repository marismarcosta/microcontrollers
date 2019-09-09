;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;*               PLACA DE APRENDIZAGEM: USTART FOR PIC		   *
;*		 PROGRAMA��O EM ASSEMBLY DO PIC18F4550		   *
;*			AUTOR: MARISMAR COSTA                      *
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
    
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;*                     ARQUIVOS DE DEFINI��ES                      *
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *	
  LIST p=18f4550, r=hex  
#INCLUDE <p18f4550.inc>		;ARQUIVO PADR�O MICROCHIP PARA 18F4550
    
; CONFIG1H
  CONFIG    FOSC    = INTOSCIO_EC   ; OSCILLATOR SELECTION BITS (INTERNAL OSCILLATOR, PORT FUNCTION ON RA6, EC USED BY USB (INTIO))
  CONFIG    LVP	    = OFF	    ; SINGLE-SUPPLY ICSP ENABLE BIT (SINGLE-SUPLY ICSP DISABLED) 
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;*                         VARI�VEIS                               *
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
; DEFINI��O DOS NOMES E ENDERE�OS DE TODAS AS VARI�VEIS UTILIZADAS 
; PELO SISTEMA

	CBLOCK	0x10		;ENDERE�O INICIAL DA MEM�RIA DE USU�RIO
		W_TEMP		;REGISTRADORES TEMPOR�RIOS PARA USO
		STATUS_TEMP	;JUNTO �S INTERRUP��ES
		
		;VARI�VEIS GERAIS
		THETA		;ANGULO DO PRIMEIRO SERVO MOTOR	
		PHI		;ANGULO DO SEGUNDO SERVO MOTOR	
		MELHOR_THETA	;MELHOR �NGULO TETA(SERVO MOTOR 1)
		MELHOR_PHI	;MELHOR �NGULO PHI(SERVO MOTOR 2)
		V_MAX_THETA	;M�XIMA TENS�O EM THETA
		V_MAX_PHI	;M�XIMA TENS�O EM PHI
		ANGULO_ATIVO	;�NGULO QUE EST� SENDO AJUSTADO, 0 - TETA / 1 - PHI
		
		;VARI�VEIS AUXILIARES PARA GERA��O DE DELAY
		CONTADOR_DELAY	;AUXILIAR NA REPETI��O DO DELAY DE 10 MICROSEGUNDOS
		FIM_PERIODO	;SINALIZA QUANDO O PERIODO DE 20 MILISEGUNDOS 
		CONTADOR_AUX    ;PARA DELAY DE COMPENSA��O DA VELOCIDADE M�XIMA DO SERVO
		DELAY1		
		DELAY2
		DELAY3

	ENDC			;FIM DO BLOCO DE MEM�RIA

;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;*                        FLAGS INTERNOS                           *
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
; DEFINI��O DE TODOS OS FLAGS UTILIZADOS PELO SISTEMA
	
	#DEFINE	FIM_PERIODO_FLAG    FIM_PERIODO,0   ;FIM_PERIODO = 0 - N�O ACABOU / 1 - ACABOU
	#DEFINE	ANGULO_ATIVO_FLAG   ANGULO_ATIVO,0  ;ANGULO_ATIVO = 0 - THETA(MOTOR1) / 1 - PHI(MOTOR2)

;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;*                         CONSTANTES                              *
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
; DEFINI��O DE TODAS AS CONSTANTES UTILIZADAS PELO SISTEMA

;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;*                           ENTRADAS                              *
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
; DEFINI��O DE TODOS OS PINOS QUE SER�O UTILIZADOS COMO ENTRADA
; RECOMENDAMOS TAMB�M COMENTAR O SIGNIFICADO DE SEUS ESTADOS (0 E 1)

;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;*                           SA�DAS                                *
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
; DEFINI��O DE TODOS OS PINOS QUE SER�O UTILIZADOS COMO SA�DA
; RECOMENDAMOS TAMB�M COMENTAR O SIGNIFICADO DE SEUS ESTADOS (0 E 1)	
	
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;*			      VETORES                              *
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

	ORG 0x0000		;ENDERE�O INICIAL DO PROGRAMA
	GOTO INICIO
	
	ORG 0x0008		;ENDERE�O DA INTERRUP��O DE ALTA PRIORIDADE
	GOTO HIGH_INT
    
	ORG 0x0018		;ENDERE�O DA INTERRUP��O DE BAIXA PRIORIDADE
	GOTO LOW_INT
    
    
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;*            IN�CIO DA INTERRUP��O DE ALTA PRIORIDADE             *
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
; ENDERE�O DE DESVIO DAS INTERRUP��ES. A PRIMEIRA TAREFA � SALVAR OS
; VALORES DE "W" E "STATUS" PARA RECUPERA��O FUTURA

HIGH_INT:
	MOVWF	W_TEMP		    ;COPIA W PARA W_TEMP
	SWAPF	STATUS,W
	MOVWF	STATUS_TEMP	    ;COPIA STATUS PARA STATUS_TEMP

;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;*            ROTINA DE INTERRUP��O DE ALTA PRIORIDADE             *
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
; AQUI SER�O ESCRITAS AS ROTINAS DE RECONHECIMENTO E TRATAMENTO DAS
; INTERRUP��ES
	BTFSC	LATA,3		    ;TESTA SE O AJUSTE DA POSI��O J� FOI FEITO
	GOTO	END_INT
	BSF	ADCON0,1	    ;DISPARA A CONVERSAO A/D
FIM_CONVERSAO			    ;ESPERA A CONVERSAO SER FINALIZADA
	BTFSC	ADCON0,1	    ;VERIFICA SE O FIM DA CONVERSAO
	GOTO	FIM_CONVERSAO	
	BTFSC	ANGULO_ATIVO_FLAG   ;TESTAR SE O ANGULO_ATIVO � PHI OU THETA
	GOTO	CONVERSAO_PHI	    ;ANGULO_ATIVO = 0 - THETA / 1 - PHI
CONVERSAO_THETA
	MOVF	ADRESH,0	    ;MOVE O VALOR DA CONVERSAO PARA WREG
	CPFSLT	V_MAX_THETA	    ;TESTA SE O NOVO VALOR CONVERTIDO � MAIOR QUE O MAIOR ANTERIORMENTE SALVO E DESVIA 
	GOTO	ANGULO_THETA	    ;SE N�O, DESVIO PARA O TRATAMENTO DO ANGULO THETA
	MOVWF	V_MAX_THETA	    ;ATUALIZA O MAIOR VALOR
	MOVFF	THETA,MELHOR_THETA  ;ATUALIZA O MELHOR ANGULO
	GOTO	ANGULO_THETA
	
CONVERSAO_PHI
	MOVF	ADRESH,0	    ;MOVE O VALOR DA CONVERSAO PARA WREG
	CPFSLT	V_MAX_PHI	    ;TESTA SE O NOVO VALOR CONVERTIDO � MAIOR QUE O MAIOR ANTERIORMENTE SALVO E DESVIA 
	GOTO	ANGULO_PHI	    ;SE N�O, DESVIO PARA O TRATAMENTO DO ANGULO THETA
	MOVWF	V_MAX_PHI	    ;ATUALIZA O MAIOR VALOR
	MOVFF	PHI,MELHOR_PHI  ;ATUALIZA O MELHOR ANGULO
	GOTO	ANGULO_PHI
	
;	BTFSC	ANGULO_ATIVO_FLAG   ;TESTAR SE O ANGULO_ATIVO � PHI OU THETA
;	GOTO	ANGULO_PHI	    ;ANGULO_ATIVO = 0 - THETA / 1 - PHI
	
ANGULO_THETA
	CLRF	WREG		    ;TESTAR SE O ANGULO � ZERO, SE FOR, ESPERA UM DELAY DE 400 MICROSEGUNDOS
	SUBWF	THETA,0		    ;VERIFICA SE O ANGULO � ZERO	
    	BTFSC	STATUS,Z	    
	GOTO	THETA_ZERO	    ;SE FOR ZERO, DESVIA PARA O DELAY ADICIONAL
INCREMENTA_THETA
	MOVLW	.40
	MOVWF	CONTADOR_AUX	    ;INICIALIZA O CONTADOR
	INCF	THETA		    ;SE N�O, INCREMENTA O �NGULO THETA
	MOVF	THETA,0		    ;COPIA O VALOR DE THETA PARA WORK
	SUBLW	.181		
	BTFSS	STATUS,Z	    ;TESTA SE THETA FOI INCREMENTADO A 181 GRAUS
	GOTO	END_INT		    ;SE THETA < 181, ENT�O DESVIA PARA O FIM DA INTERRUP��O 
	CLRF	THETA		    ;SE THETA FOR 181, ENTAO THETA RETORNA A 0 GRAUS
	MOVLW	.1
	MOVWF	ANGULO_ATIVO	    ;ALTERA O ANGULO_ATIVO PARA PHI
	GOTO	END_INT
	
ANGULO_PHI
	CLRF	WREG		    ;TESTAR SE O ANGULO � ZERO, SE FOR, ESPERA UM DELAY DE 400 MICROSEGUNDOS
	SUBWF	PHI,0		    ;VERIFICA SE O ANGULO � ZERO	
    	BTFSC	STATUS,Z	    
	GOTO	PHI_ZERO	    ;SE FOR ZERO, DESVIA PARA O DELAY ADICIONAL
INCREMENTA_PHI
	MOVLW	.40
	MOVWF	CONTADOR_AUX	    ;INICIALIZA O CONTADOR
	INCF	PHI		    ;INCREMENTA O �NGULO PHI
	MOVF	PHI,0		    ;COPIA O VALOR DE PHI PARA WORK
	SUBLW	.181		
	BTFSS	STATUS,Z	    ;TESTA SE PHI FOI INCREMENTADO A 181 GRAUS
	GOTO	END_INT		    ;SE PHI < 181, ENT�O DESVIA PARA O FIM DA INTERRUP��O
	;CLRF	PHI		    ;SE PHI FOR 181, ENTAO PHI RETORNA A 0 GRAUS
	MOVFF	MELHOR_PHI,PHI	    
	MOVFF	MELHOR_THETA,THETA
	BSF	LATA,3		    ;SINALIZA QUE ACABOU O AJUSTE DA POSICAO
	CLRF	ANGULO_ATIVO	    ;ALTERA O ANGULO_ATIVO PARA THETA
	GOTO	END_INT
	
THETA_ZERO
	DECFSZ	CONTADOR_AUX	    ;DECREMENTA O CONTADOR AT� ATINGIR ZERO
	GOTO	END_INT
	GOTO	INCREMENTA_THETA
	
PHI_ZERO   
	DECFSZ	CONTADOR_AUX	    ;DECREMENTA O CONTADOR AT� ATINGIR ZERO
	GOTO	END_INT
	GOTO	INCREMENTA_PHI
	
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;*       ROTINA DE SA�DA DA INTERRUP��O DE ALTA PRIORIDADE         *
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
; OS VALORES DE "W" E "STATUS" DEVEM SER RECUPERADOS ANTES DE 
; RETORNAR DA INTERRUP��O

END_INT:
	BCF	INTCON,TMR0IF	    ;INTERRUP��O POR TIMER0, LIMPA A FLAG
	BSF	FIM_PERIODO_FLAG    ;SETA O SINALIZADOR DO FIM DO PERIODO DE 20 MILISEGUNDOS
	SWAPF	STATUS_TEMP,W
	MOVWF	STATUS		    ;MOVE STATUS_TEMP PARA STATUS
	SWAPF	W_TEMP,F
	SWAPF	W_TEMP,W	    ;MOVE W_TEMP PARA W
	RETFIE
    
	
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;*            IN�CIO DA INTERRUP��O DE BAIXA PRIORIDADE            *
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
; ENDERE�O DE DESVIO DAS INTERRUP��ES. A PRIMEIRA TAREFA � SALVAR OS
; VALORES DE "W" E "STATUS" PARA RECUPERA��O FUTURA
	
LOW_INT:
	MOVWF	W_TEMP		;COPIA W PARA W_TEMP
	SWAPF	STATUS,W
	MOVWF	STATUS_TEMP	;COPIA STATUS PARA STATUS_TEMP

;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;*           ROTINA DE INTERRUP��O DE BAIXA PRIORIDADE             *
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
; AQUI SER�O ESCRITAS AS ROTINAS DE RECONHECIMENTO E TRATAMENTO DAS
; INTERRUP��ES
	
	NOP
	
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;*      ROTINA DE SA�DA DA INTERRUP��O DE BAIXA PRIORIDADE         *
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
; OS VALORES DE "W" E "STATUS" DEVEM SER RECUPERADOS ANTES DE 
; RETORNAR DA INTERRUP��O
	
	SWAPF	STATUS_TEMP,W
	MOVWF	STATUS		;MOVE STATUS_TEMP PARA STATUS
	SWAPF	W_TEMP,F
	SWAPF	W_TEMP,W	;MOVE W_TEMP PARA W
	RETFIE
    
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;*	            	 ROTINAS E SUBROTINAS                      *
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
; CADA ROTINA OU SUBROTINA DEVE POSSUIR A DESCRI��O DE FUNCIONAMENTO
; E UM NOME COERENTE �S SUAS FUN��ES.

DELAY_600U
	;CORPO DA ROTINA1
	CLRF	DELAY1
	MOVLW	.10		;VALOR INICIAL DO DELAY2
	MOVWF	DELAY2
LOOP1
	DECFSZ	DELAY1		
	GOTO	LOOP1
	DECFSZ	DELAY2
	GOTO	LOOP1
	RETURN
	
	
DELAY_AUXILIAR
	;CORPO DA ROTINA2
	CLRF	WREG		;LIMPA O REGISTRADOR WORK
	SUBWF	CONTADOR_DELAY,0;SE CONTADOR FOR 0, DESVIA PARA O RETORNO DA SUBROTINA
	BTFSC	STATUS,Z	;TESTA O BIT ZERO DO STATUS
	RETURN			;N�O EXECUTA O DELAY, POIS O ANGULO � 0 
DELAY_10U
	MOVLW	.40		;VALOR INICIAL DO DELAY2
	MOVWF	DELAY3		
LOOP2				;CADA CICLO EQUIVALE A 10USEGUNDOS    
	DECFSZ	DELAY3
	GOTO	LOOP2
	DECFSZ	CONTADOR_DELAY	;REPETE O CICLO V�RIAS VEZES DE ACORDO COM O �NGULO
	GOTO	DELAY_10U
	RETURN

;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;*                     INICIO DO PROGRAMA                          *
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
	
INICIO:
	MOVLW	B'00000001'	;TRISA DEFINE AS PORTAS RA<7:0> COMO ENTRADAS OU SA�DAS
	MOVWF	TRISA		;1 - ENTRADA/ 0 - SA�DA		
	MOVLW	B'10000001'	;CONFIGURA��O DO TIMER0
	MOVWF	T0CON
	MOVLW	B'11100000'	;CONFIGURA��O DA INTERRUP��O PELO TIMER0
	MOVWF	INTCON
	MOVLW	B'00000100'	;A INTERRUO��O DO TIMER0 � DEFINIDA COMO ALTA
	MOVWF	INTCON2
	MOVLW	B'00001110'	;CONFIGURA RA0 COMO CANAL ANAL�GICO(AN0)
	MOVWF	ADCON1 
	MOVLW	B'00000000'	;M�DULO COMPARADOR DESATIVADO
	MOVWF	CMCON 
	MOVLW	B'00000110'	;CONFIGURA O FOSC DO CONVERSOR A/D
	MOVWF	ADCON2
	MOVLW	B'00000001'	;HABILITA O CONVERSOR A/D
	MOVWF	ADCON0
	CLRF	PORTA		;LIMPA AS SA�DAS RA<7:0>
	CLRF	LATA

;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;*                     INICIALIZA��O DAS VARI�VEIS                 *
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
			
	CLRF	THETA		;�NGULO INICIAL: 0 GRAUS
	CLRF	PHI		;�NGULO INICIAL: 0 GRAUS
	CLRF	ANGULO_ATIVO	;INICIALIZA O PROGRAMA AJUSTANDO O THETA(MOTOR1)
	CLRF	FIM_PERIODO	;FIM_PERIODO = 0
	CLRF	CONTADOR_DELAY	;INICIALIZA COMO ZERO 
	MOVLW	.40
	MOVWF	CONTADOR_AUX	;INICIALIZA EM 40
	
	
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;*                     ROTINA PRINCIPAL                            *
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
MAIN
	;CORPO DA ROTINA PRINCIPAL
	BTFSC	ANGULO_ATIVO_FLAG   ;VERIFICA QUAL O ANGULO DEVE SER AJUSTADO	
	GOTO	ALTERA_PHI	    ;SE MOTOR_ATIVO = 1, ANGULO_ATIVO = PHI
	
	BSF	LATA,1		    ;SE MOTOR_ATIVO = 0, ANGULO_ATIVO = THETA
	BCF	FIM_PERIODO_FLAG    ;LIMPA O SINALIZADOR DO T�RMINO DO PER�ODO
	CALL	DELAY_600U	    ;PERMANECE POR 600USEGUNDOS
	MOVFF	THETA,CONTADOR_DELAY;MAIS THETA*10USEGUNDOS EM N�VEL ALTO
	CALL	DELAY_AUXILIAR	    ;CONTADOR � INICIALIZADO COM O VALOR DO �NGULO
	BCF	LATA,1		    ;AT� O PER�ODO TERMINAR, RA1 = 0	
	GOTO	TERMINOU_PERIODO    ;ESPERA O PER�ODO DE 20 MILISEGUNDOS ACABAR
	
ALTERA_PHI
	BSF	LATA,2		    ;RA2 EQUIVALE AO SINAL DO SERVO MOTOR 2, PHI
	BCF	FIM_PERIODO_FLAG    ;LIMPA O SINALIZADOR DO T�RMINO DO PER�ODO
	CALL	DELAY_600U	    ;PERMANECE POR 600USEGUNDOS
	MOVFF	PHI,CONTADOR_DELAY  ;MAIS PHI*10USEGUNDOS EM N�VEL ALTO
	CALL	DELAY_AUXILIAR	    ;CONTADOR � INICIALIZADO COM O VALOR DO �NGULO
	BCF	LATA,2		    ;AT� O PER�ODO TERMINAR, RA2 = 0	
	
TERMINOU_PERIODO
	BTFSS	FIM_PERIODO_FLAG    ;FIM_PERIODO = 0 - N�O ACABOU / 1 - ACABOU
	GOTO	TERMINOU_PERIODO    ;AGUARDA AT� O FIM DO PER�ODO DE 20MSEGUNDOS
	GOTO	MAIN		    ;ACABOU, RETORNA AO MAIN


;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;*                       FIM DO PROGRAMA                           *
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

	END