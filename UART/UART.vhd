----------------------------------------------------------------------------------
-- Company:         CEA
-- Engineer:        Tom Désesquelle
-- 
-- Create Date:     02.03.2023
-- Design Name:     UART
-- Module Name:     UART - Behavioral
-- Project Name:    
-- Target Devices:  
-- Tool Versions:   VIVADO 2018.3
-- Description:     RECONFIGURABLE UNIVERSAL ASYNCHRONOUS RECEIVER TRANSMITTER MODULE
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity UART is
    GENERIC (
                DATA_FRAME      :   POSITIVE RANGE 5 TO 9   :=  8                   ;
                PARITY          :   STRING                  :=  "ODD"               ;
                STOPBITS        :   REAL                    :=  1.0                 ;
                BAUDRATE        :   POSITIVE                :=  9600    
            );
    PORT    (
                inClock         :   IN  STD_LOGIC                                   ;
                inReset         :   IN  STD_LOGIC                                   ;
                inData          :   IN  STD_LOGIC_VECTOR(DATA_FRAME-1 DOWNTO 0)     ;
                inEnable        :   IN  STD_LOGIC                                   ;
                inRx            :   IN  STD_LOGIC                                   ;
                outTx           :   OUT STD_LOGIC                                   ;
                outData         :   OUT STD_LOGIC_VECTOR(DATA_FRAME-1 DOWNTO 0)     ;
                outReady        :   OUT STD_LOGIC                                   ;
                outValid        :   OUT STD_LOGIC                                   ;
                outTxProcess    :   OUT STD_LOGIC                                   ;
                outRxProcess    :   OUT STD_LOGIC                                   ;
                outError        :   OUT STD_LOGIC                                   
            );
end UART;

architecture Behavioral of UART is

--***********************************************************************************
--  TYPE DECLARATIONS
--***********************************************************************************
TYPE    STATE   IS  (IDLE, UART_Tx_START, UART_Tx_WAIT_END, UART_Rx_START, UART_Rx_WAIT_END, UART_Rx_VALID);
--***********************************************************************************

--***********************************************************************************
--  CONSTANT DECLARATIONS
--***********************************************************************************
constant    CLOCK_PERIOD    :   POSITIVE                        :=  100000000                                       ;
constant    BIT_TMR_MAX     :   INTEGER RANGE 0 TO 2**15 - 1    :=  INTEGER(REAL(CLOCK_PERIOD)/REAL(BAUDRATE)) - 1  ;
--***********************************************************************************

--***********************************************************************************
--  SIGNAL DECLARATIONS
--***********************************************************************************
signal      sigEnable       :   STD_LOGIC                       :=  '0'     ;
signal      sigRx           :   STD_LOGIC                       :=  '1'     ;
signal      sigValid        :   STD_LOGIC                       :=  '0'     ;
signal      sigReady        :   STD_LOGIC                       :=  '0'     ;
signal      ERROR_Tx        :   STD_LOGIC                       :=  '0'     ;
signal      ERROR_Rx        :   STD_LOGIC                       :=  '0'     ;

signal      currentState    :   STATE                           :=  IDLE    ;
signal      nextState       :   STATE                           :=  IDLE    ;
--***********************************************************************************

begin

--***********************************************************************************
--  COMPONENT INSTANTIATIONS
--***********************************************************************************       
UART_Tx :   entity work.UART_Tx
    GENERIC MAP (
        DATA_FRAME  =>  DATA_FRAME  ,
        PARITY      =>  PARITY      ,
        STOPBITS    =>  STOPBITS    ,
        BAUDRATE    =>  BAUDRATE    
    )
    PORT MAP (
        inClock     =>  inClock     ,
        inReset     =>  inReset     ,
        inData      =>  inData      ,
        inEnable    =>  sigEnable   ,
        outTx       =>  outTx       ,
        outReady    =>  sigReady    ,
        outError    =>  ERROR_Tx       
    );

UART_Rx :   entity work.UART_Rx
    GENERIC MAP (
        DATA_FRAME  =>  DATA_FRAME  ,
        PARITY      =>  PARITY      ,
        STOPBITS    =>  STOPBITS    ,
        BAUDRATE    =>  BAUDRATE    
    )
    PORT MAP (
        inClock     =>  inClock     ,
        inReset     =>  inReset     ,
        inRx        =>  sigRx       ,
        outData     =>  outData     ,
        outValid    =>  sigValid    ,
        outError    =>  ERROR_Rx       
    );
--***********************************************************************************

--***********************************************************************************
--  BEHAVIOUR
--***********************************************************************************
stateProcess : process(inClock, inReset)
--  SWITCH FROM ONE STATE TO ANOTHER
begin
    if(inReset = '0') then
        currentState    <=  IDLE            ;
    elsif(inClock = '1' and inClock'event) then
        currentState    <=  nextState       ;
    else
        currentState    <=  currentState    ;
    end if;
end process;

fsmProcess : process(currentState, inEnable, inRx, sigReady, sigValid, ERROR_Rx, ERROR_Tx)
--  FSM TO SWITCH BETWEEN RX & TX STATE
begin
    CASE currentState IS
                          
        when    IDLE                =>
                                            if(inEnable = '1') then
                                                nextState   <=  UART_Tx_START       ;
                                            elsif(inRx = '0') then
                                                nextState   <=  UART_Rx_START       ;
                                            else
                                                nextState   <=  IDLE                ;
                                            end if;
                                              
        when    UART_Tx_START       =>
                                                nextState   <=  UART_Tx_WAIT_END    ;
                                                
        when    UART_Tx_WAIT_END    =>
                                            if(sigReady = '1') then
                                                nextState   <=  IDLE                ;
                                            elsif(ERROR_Tx = '1') then
                                                nextState   <=  IDLE                ;
                                            else
                                                nextState   <=  UART_Tx_WAIT_END    ;
                                            end if;
                                              
        when    UART_Rx_START       =>
                                                nextState   <=  UART_Rx_WAIT_END    ;
                                                
        when    UART_Rx_WAIT_END    =>
                                            if(sigValid = '1') then
                                                nextState   <=  UART_Rx_VALID       ;
                                            elsif(ERROR_Rx = '1') then
                                                nextState   <=  IDLE                ;
                                            else
                                                nextState   <=  UART_Rx_WAIT_END    ;
                                            end if;                                                

        when    UART_Rx_VALID       =>
                                            if(sigValid = '0') then
                                                nextState   <=  IDLE                ;
                                            elsif(ERROR_Rx = '1') then
                                                nextState   <=  IDLE                ;
                                            else
                                                nextState   <=  UART_Rx_VALID       ;
                                            end if;
                                              
        when    OTHERS              =>
                                                nextState   <=  IDLE                ;

    end case;
end process;
--***********************************************************************************

--***********************************************************************************
--  INTERNAL SIGNAL ASSIGNMENTS
--***********************************************************************************
sigEnable       <=  '1'     when    (currentState = UART_Tx_START)      else    
                    '0'                                                 ;

sigRx           <=  '0'     when    (currentState = UART_Rx_START)      else
                    inRx    when    (currentState = UART_Rx_WAIT_END)   else
                    inRx    when    (currentState = UART_Rx_VALID)      else
                    inRx    when    (currentState = IDLE)               else
                    '1'                                                 ;
--***********************************************************************************

--***********************************************************************************
--  OUTPUTS ASSIGNMENTS
--*********************************************************************************** 
outReady        <=  sigReady                                            ;

outValid        <=  sigValid                                            ;

outTxProcess    <=  '1'     when    (currentState = UART_Tx_START)      else
                    '1'     when    (currentState = UART_Tx_WAIT_END)   else
                    '0'                                                 ;


outRxProcess    <=  '1'     when    (currentState = UART_Rx_START)      else
                    '1'     when    (currentState = UART_Rx_WAIT_END)   else
                    '1'     when    (currentState = UART_Rx_VALID)      else
                    '0'                                                 ;

outError    <=  ERROR_Rx OR ERROR_Tx    ;
--*********************************************************************************** 


end Behavioral;
