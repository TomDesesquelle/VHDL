----------------------------------------------------------------------------------
-- Company:         CEA
-- Engineer:        Tom Désesquelle
-- 
-- Create Date:     01.03.2023
-- Design Name:     UART_Tx
-- Module Name:     UART_Tx - Behavioral
-- Project Name:    
-- Target Devices:  
-- Tool Versions:   VIVADO 2018.3
-- Description:     RECONFIGURABLE UNIVERSAL ASYNCHRONOUS RECEIVER TRANSMITTER Tx MODULE
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity UART_Tx is
    GENERIC (
                DATA_FRAME  :   POSITIVE RANGE 5 TO 9   :=  8                   ;
                PARITY      :   STRING                  :=  "ODD"               ;
                STOPBITS    :   REAL                    :=  1.0                 ;
                BAUDRATE    :   POSITIVE                :=  9600    
            );
    PORT    (
                inClock     :   IN  STD_LOGIC                                   ;
                inReset     :   IN  STD_LOGIC                                   ;
                inData      :   IN  STD_LOGIC_VECTOR(DATA_FRAME-1 DOWNTO 0)     ;
                inEnable    :   IN  STD_LOGIC                                   ;
                outTx       :   OUT STD_LOGIC                                   ;
                outReady    :   OUT STD_LOGIC                                   ;
                outError    :   OUT STD_LOGIC                                   
            );
end UART_Tx;

architecture Behavioral of UART_Tx is

--***********************************************************************************
--  TYPE DECLARATIONS
--***********************************************************************************
TYPE    STATE   IS  (START, START_BIT, SHIFT, HOLD, PARITY_ENABLE, STOP_1BIT, STOP_HALFBIT, STOP_2BIT, CONFIG_ERROR);
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
signal      dataCounter     :   INTEGER RANGE 0 TO 15                       :=  0               ;
signal      holdCounter     :   INTEGER RANGE 0 TO 2**15 - 1                :=  0               ;

signal      dataToSend      :   STD_LOGIC_VECTOR(DATA_FRAME-1 DOWNTO 0)     :=  (others => '0') ;
signal      parityBit       :   STD_LOGIC                                   :=  '0'             ;

signal      currentState    :   STATE                                       :=  START           ;
signal      nextState       :   STATE                                       :=  START           ;
--***********************************************************************************

begin

--***********************************************************************************
--  COUNTERS
--***********************************************************************************
dataCounterProcess : process(inClock, inReset, currentState)    --  dataCounter
--  COUNT THE SHIFTED DATA
begin
    if(inReset = '0') then
			dataCounter     <=  0                   ;
    elsif(inClock'event and inClock = '1') then
        if(currentState = SHIFT) then
            dataCounter     <=  dataCounter + 1     ;
        elsif(currentState = HOLD) then
            dataCounter     <=  dataCounter         ;
        else
			dataCounter     <=  0                   ;
		end if;
    else
			dataCounter     <=  dataCounter         ;
    end if;
end process;

holdCounterProcess : process(inClock, inReset, holdCounter, currentState)
--  COUNTER TO HOLD DATA FOR THE RIGHT BAUDRATE
begin
    if(inReset = '0') then
                holdCounter     <=  0                   ;
    elsif(inClock'event and inClock = '1') then
        if(holdCounter = BIT_TMR_MAX - 1) then
                holdCounter     <=  0                   ;
        else
            if(currentState = START_BIT) then
                holdCounter     <=  holdCounter + 1     ;
            elsif(currentState = HOLD) then
                holdCounter     <=  holdCounter + 1     ;
            elsif(currentState = PARITY_ENABLE) then
                holdCounter     <=  holdCounter + 1     ;
            elsif(currentState = STOP_1BIT) then
                holdCounter     <=  holdCounter + 1     ;
            elsif(currentState = STOP_HALFBIT) then
                holdCounter     <=  holdCounter + 1     ;
            elsif(currentState = STOP_2BIT) then
                holdCounter     <=  holdCounter + 1     ;
            else
                holdCounter     <=  0                   ;
            end if;
        end if;
    else
                holdCounter     <=  holdCounter         ;
    end if;
end process;
--***********************************************************************************

--***********************************************************************************
--  BEHAVIOUR
--***********************************************************************************
stateProcess : process(inClock, inReset)
--  SWITCH FROM ONE STATE TO ANOTHER
begin
    if(inReset = '0') then
        currentState    <=  START           ;
    elsif(inClock = '1' and inClock'event) then
        currentState    <=  nextState       ;
    else
        currentState    <=  currentState    ;
    end if;
end process;

fsmProcess : process(currentState, inEnable, holdCounter, dataCounter)
--  FSM TO SEND DATA THROUGH THE UART
begin
    CASE currentState IS
                          
        when    START           =>
                                        if(inEnable = '1') then
                                                    nextState   <=  START_BIT       ;
                                        else
                                                    nextState   <=  START           ;
                                        end if;
                                     
        when    START_BIT       =>
                                        if(holdCounter = BIT_TMR_MAX - 1) then
                                                    nextState   <=  SHIFT           ;
                                        else
                                                    nextState   <=  START_BIT       ;
                                        end if;
                                    
        when    SHIFT           =>
                                                    nextState   <=  HOLD            ;
                                    
        when    HOLD            =>
                                        if(holdCounter = BIT_TMR_MAX - 1) then
                                            if(dataCounter = DATA_FRAME) then
                                                if(PARITY = "NONE") then
                                                    nextState   <=  STOP_1BIT       ;
                                                elsif(PARITY = "ODD") then
                                                    nextState   <=  PARITY_ENABLE   ;
                                                elsif(PARITY = "EVEN") then
                                                    nextState   <=  PARITY_ENABLE   ;
                                                else
                                                    nextState   <=  CONFIG_ERROR    ;  
                                                end if;
                                            else
                                                    nextState   <=  SHIFT           ;
                                            end if;
                                        else
                                                    nextState   <=  HOLD            ;
                                        end if;
                                    
        when    PARITY_ENABLE   =>
                                        if(holdCounter = BIT_TMR_MAX - 1) then
                                                    nextState   <=  STOP_1BIT       ;
                                        else
                                                    nextState   <=  PARITY_ENABLE   ;
                                        end if;
                                        
        when    STOP_1BIT       =>
                                        if(holdCounter = BIT_TMR_MAX - 1) then
                                            if(STOPBITS = 1.5) then
                                                    nextState   <=  STOP_HALFBIT    ;
                                            elsif(STOPBITS = 2.0) then
                                                    nextState   <=  STOP_2BIT       ;
                                            elsif(STOPBITS = 1.0) then
                                                    nextState   <=  START           ;
                                            else
                                                    nextState   <=  CONFIG_ERROR    ;
                                            end if;
                                        else
                                                    nextState   <=  STOP_1BIT       ;
                                        end if;
                                        
        when    STOP_HALFBIT    =>
                                        if(holdCounter = BIT_TMR_MAX/2 - 1) then
                                                    nextState   <=  START           ;
                                        else
                                                    nextState   <=  STOP_HALFBIT    ;
                                        end if;
                                                
        when    STOP_2BIT       =>
                                        if(holdCounter = BIT_TMR_MAX - 1) then
                                                    nextState   <=  START           ;
                                        else
                                                    nextState   <=  STOP_2BIT       ;
                                        end if;
        
        when    CONFIG_ERROR    =>
                                                    nextState <=  START       ;  
                                              
        when    OTHERS          =>
                                                    nextState <=  START       ;
                                    
    end case;
end process;
--***********************************************************************************


--***********************************************************************************
--  INTERNAL SIGNAL ASSIGNMENTS
--***********************************************************************************
dataToSendProcess : process(inClock, inReset, currentState, inData)
-- STORE DATA TO BE SENT THROUGH THE UART
begin
    if(inReset = '0') then
            dataToSend  <=  (others => '0') ;
    elsif(inClock'event AND inClock = '1') then
        if(currentState = START) then
            dataToSend  <=  inData          ;
        else
            dataToSend  <=  dataToSend      ;
        end if;
    else
            dataToSend  <=  dataToSend      ;
    end if;
end process;

parityBitProcess : process(inClock, inReset, currentState)
--  CALCULATE THE PARITY OF THE DATA
begin
    if(inReset = '0') then
        if(PARITY = "EVEN") then
                parityBit   <=  '0'                                     ;
        elsif(PARITY = "ODD") then
                parityBit   <=  '1'                                     ;
        else
                parityBit   <=  '0'                                     ;
        end if;
    elsif(inClock'event AND inClock = '1') then
        if(currentState = START) then
            if(PARITY = "EVEN") then
                parityBit   <=  '0'                                     ;
            elsif(PARITY = "ODD") then
                parityBit   <=  '1'                                     ;
            else
                parityBit   <=  '0'                                     ;
            end if;
        elsif(currentState = SHIFT) then
                parityBit   <=  parityBit XOR dataToSend(dataCounter)   ;
        else
                parityBit   <=  parityBit                               ;
        end if;
    else
                parityBit   <=  parityBit                               ;
    end if;
end process;
--***********************************************************************************


--***********************************************************************************
--  OUTPUTS ASSIGNMENTS
--*********************************************************************************** 

-- SENT VALUE ON THE UART LINE
outTx       <=  '1'                         when    (currentState = START)          else
                '0'                         when    (currentState = START_BIT)      else
                dataToSend(dataCounter)     when    (currentState = SHIFT)          else
                dataToSend(dataCounter - 1) when    (currentState = HOLD)           else
                parityBit                   when    (currentState = PARITY_ENABLE)  else
                '1'                         when    (currentState = STOP_1BIT)      else                
                '1'                         when    (currentState = STOP_HALFBIT)   else                
                '1'                         when    (currentState = STOP_2BIT)      else
                '1'                                                                 ;
                
--  UART IS READY TO SEND A NEW DATA
outReady    <=  '1'                         when    (currentState = START)          else
                '0'                                                                 ;

--  ERROR DETECTED
outError    <=  '1'                         when    (currentState = CONFIG_ERROR)   else
                '0'                                                                 ;
--*********************************************************************************** 

end Behavioral;
