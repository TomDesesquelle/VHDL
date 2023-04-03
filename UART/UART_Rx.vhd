----------------------------------------------------------------------------------
-- Company:         CEA
-- Engineer:        Tom Désesquelle
-- 
-- Create Date:     01.03.2023
-- Design Name:     UART_Rx
-- Module Name:     UART_Rx - Behavioral
-- Project Name:    DRAM_CONTROLLER
-- Target Devices:  xc7s50csga324
-- Tool Versions:   VIVADO 2018.3
-- Description:     RECONFIGURABLE UNIVERSAL ASYNCHRONOUS RECEIVER TRANSMITTER Rx MODULE
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity UART_Rx is
    GENERIC (
                DATA_FRAME  :   POSITIVE RANGE 5 TO 9   :=  8                   ;
                PARITY      :   STRING                  :=  "ODD"               ;
                STOPBITS    :   REAL                    :=  1.0                 ;
                BAUDRATE    :   POSITIVE                :=  9600    
            );
    PORT    (
                inClock     :   IN  STD_LOGIC                                   ;
                inReset     :   IN  STD_LOGIC                                   ;
                inRx        :   IN  STD_LOGIC                                   ;
                outData     :   OUT STD_LOGIC_VECTOR(DATA_FRAME-1 DOWNTO 0)     ;
                outValid    :   OUT STD_LOGIC                                   ;
                outError    :   OUT STD_LOGIC                                   
            );
end UART_Rx;

architecture Behavioral of UART_Rx is

--***********************************************************************************
--  TYPE DECLARATIONS
--***********************************************************************************
TYPE    STATE   IS  (
                        START, VALID_START_BIT, SHIFT, SAMPLE, PARITY_SAMPLE, PARITY_VALID, STOP_1BIT, STOP_1BIT_VALID, 
                        STOP_2BIT, STOP_2BIT_VALID, STOP_HALFBIT, STOP_HALFBIT_VALID, END_Rx, CONFIG_ERROR
                    );
--***********************************************************************************

--***********************************************************************************
--  CONSTANT DECLARATIONS
--***********************************************************************************
constant    CLOCK_PERIOD        :   POSITIVE                        :=  100000000                                       ;
constant    BIT_TMR_MAX         :   INTEGER RANGE 0 TO 2**15 - 1    :=  INTEGER(REAL(CLOCK_PERIOD)/REAL(BAUDRATE)) - 1  ;
constant    BIT_TMR_HALF        :   INTEGER RANGE 0 TO 2**14 - 1    :=  BIT_TMR_MAX/2                                   ;
--***********************************************************************************

--***********************************************************************************
--  SIGNAL DECLARATIONS
--***********************************************************************************
signal      dataCounter         :   INTEGER RANGE 0 TO 15                       :=  0               ;
signal      holdCounter         :   INTEGER RANGE 0 TO 2**15 - 1                :=  0               ;
signal      holdHalfCounter     :   INTEGER RANGE 0 TO 2**14 - 1                :=  0               ;

signal      receivedData        :   STD_LOGIC_VECTOR(DATA_FRAME-1 DOWNTO 0)     :=  (others => '0') ;
signal      holdData            :   STD_LOGIC_VECTOR(DATA_FRAME-1 DOWNTO 0)     :=  (others => '0') ;
signal      calculatedParityBit :   STD_LOGIC                                   :=  '0'             ;
signal      sampledParityBit    :   STD_LOGIC                                   :=  '0'             ;
signal      valid               :   STD_LOGIC                                   :=  '0'             ;

signal      currentState        :   STATE                                       :=  START           ;
signal      nextState           :   STATE                                       :=  START           ;
--***********************************************************************************

begin

--***********************************************************************************
--  COUNTERS
--***********************************************************************************
dataCounterProcess : process(inClock, inReset, dataCounter, currentState)
--  COUNT THE SHIFTED DATA
begin
    if(inReset = '0') then
                dataCounter     <=  0                   ;
    elsif(inClock'event and inClock = '1') then
        if(dataCounter > DATA_FRAME - 1) then
                dataCounter     <=  0                   ;
        else
            if(currentState = SAMPLE) then
                dataCounter     <=  dataCounter + 1     ;
            elsif(currentState = SHIFT) then
                dataCounter     <=  dataCounter         ;
            else
                dataCounter     <=  0                   ;
            end if;
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
            if(currentState = SHIFT) then
                holdCounter     <=  holdCounter + 1     ;
            elsif(currentState = PARITY_VALID) then
                holdCounter     <=  holdCounter + 1     ;
            elsif(currentState = STOP_1BIT) then
                holdCounter     <=  holdCounter + 1     ;
            elsif(currentState = STOP_2BIT) then
                holdCounter     <=  holdCounter + 1     ;
            elsif(currentState = STOP_HALFBIT) then
                holdCounter     <=  holdCounter + 1     ;
            else
                holdCounter     <=  0                   ;
            end if;
        end if;
    else
                holdCounter     <=  holdCounter         ;
    end if;
end process;

holdHalfCounterProcess : process(inClock, inReset, holdCounter, currentState)
--  COUNTER TO HOLD DATA FOR THE RIGHT BAUDRATE
begin
    if(inReset = '0') then
                holdHalfCounter     <=  0                       ;
    elsif(inClock'event and inClock = '1') then
        if(holdHalfCounter = BIT_TMR_HALF - 1) then
                holdHalfCounter     <=  0                       ;
        else
            if(currentState = VALID_START_BIT) then
                holdHalfCounter     <=  holdHalfCounter + 1     ;
            elsif(currentState = END_Rx) then
                holdHalfCounter     <=  holdHalfCounter + 1     ;
            else
                holdHalfCounter     <=  0                       ;
            end if;
        end if;
    else
                holdHalfCounter     <=  holdHalfCounter         ;
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

fsmProcess : process(currentState, inRx, holdHalfCounter, holdCounter, dataCounter)
--  FSM TO SEND DATA THROUGH THE UART
begin
    CASE currentState IS
                          
        when    START               =>
                                            if(inRx = '0') then
                                                        nextState   <=  VALID_START_BIT ;
                                            else
                                                        nextState   <=  START           ;
                                            end if;
                                     
        when    VALID_START_BIT     =>
                                            if(inRx = '0') then
                                                if(holdHalfCounter = BIT_TMR_HALF - 1) then
                                                        nextState   <=  SHIFT           ;
                                                else
                                                        nextState   <=  VALID_START_BIT ;
                                                end if;
                                            else
                                                        nextState   <=  CONFIG_ERROR    ;
                                            end if;
                                    
        when    SHIFT               =>
                                            if(holdCounter = BIT_TMR_MAX - 1) then
                                                        nextState   <=  SAMPLE          ;
                                            else
                                                        nextState   <=  SHIFT           ;
                                            end if;
                                    
        when    SAMPLE              =>
                                            if(dataCounter = DATA_FRAME - 1) then           
                                                if(PARITY = "EVEN") then                                    
                                                        nextState   <=  PARITY_VALID    ;
                                                elsif(PARITY = "ODD") then                                    
                                                        nextState   <=  PARITY_VALID   ;
                                                elsif(PARITY = "NONE") then                                    
                                                        nextState   <=  STOP_1BIT       ;
                                                else
                                                        nextState   <=  CONFIG_ERROR    ;
                                                end if;
                                            else
                                                        nextState   <=  SHIFT           ;
                                            end if;
                                                          
        when    PARITY_VALID        =>
                                            if(holdCounter = BIT_TMR_MAX - 1) then
                                                        nextState   <=  PARITY_SAMPLE   ;
                                            else
                                                        nextState   <=  PARITY_VALID    ;
                                            end if;
                                    
        when    PARITY_SAMPLE       =>
                                                        nextState   <=  STOP_1BIT       ;
                                                                                           
        when    STOP_1BIT           =>
                                            if(holdCounter = BIT_TMR_MAX - 1) then
                                                        nextState   <=  STOP_1BIT_VALID ;
                                            else
                                                        nextState   <=  STOP_1BIT       ;
                                            end if;
        
        when    STOP_1BIT_VALID     =>
                                            if(inRx = '1') then
                                                if(STOPBITS = 1.0) then
                                                        nextState   <=  END_Rx          ;
                                                elsif(STOPBITS = 2.0) then
                                                        nextState   <=  STOP_2BIT       ;
                                                elsif(STOPBITS = 1.5) then
                                                        nextState   <=  STOP_HALFBIT    ;
                                                else
                                                        nextState   <=  CONFIG_ERROR    ;
                                                end if;
                                            else
                                                        nextState   <=  CONFIG_ERROR    ;
                                            end if;  
                                                                                                     
        when    STOP_2BIT           =>
                                            if(holdCounter = BIT_TMR_MAX - 1) then
                                                        nextState   <=  STOP_2BIT_VALID ;
                                            else
                                                        nextState   <=  STOP_2BIT       ;
                                            end if;
        
        when    STOP_2BIT_VALID     =>
                                            if(inRx = '1') then
                                                        nextState   <=  END_Rx          ;
                                            else
                                                        nextState   <=  CONFIG_ERROR    ;
                                            end if;  
                                                                                                     
        when    STOP_HALFBIT        =>
                                            if(holdCounter = BIT_TMR_MAX - BIT_TMR_HALF/2) then
                                                        nextState   <=  STOP_HALFBIT_VALID ;
                                            else
                                                        nextState   <=  STOP_HALFBIT       ;
                                            end if;
        
        when    STOP_HALFBIT_VALID  =>
                                            if(inRx = '1') then
                                                        nextState   <=  END_Rx          ;
                                            else
                                                        nextState   <=  CONFIG_ERROR    ;
                                            end if;  
                                            
        when    END_Rx              =>  
                                            if(STOPBITS = 1.0 OR STOPBITS = 2.0) then
                                                if(holdHalfCounter = BIT_TMR_HALF - 1) then
                                                        nextState   <=  START           ;
                                                else
                                                        nextState   <=  END_Rx          ;
                                                end if;
                                            elsif(STOPBITS = 1.5) then
                                                if(holdHalfCounter = BIT_TMR_HALF/2) then
                                                        nextState   <=  START           ;
                                                else
                                                        nextState   <=  END_Rx          ;
                                                end if;
                                            else
                                                        nextState   <=  CONFIG_ERROR    ;
                                            end if;
                           
        when    CONFIG_ERROR        =>
                                                        nextState <=  START             ;  
                                              
        when    OTHERS              =>
                                                        nextState <=  START             ;
                                    
    end case;
end process;
--***********************************************************************************


--***********************************************************************************
--  INTERNAL SIGNAL ASSIGNMENTS
--***********************************************************************************
receivedDataProcess : process(inClock, inReset, currentState)
-- SHIFT THE RECEIVED DATA BIT
begin
    if(inReset = '0') then
            receivedData    <=  (others => '0')                             ;
    elsif(inClock'event AND inClock = '1') then
        if(currentState = SAMPLE) then
            receivedData    <=  inRx & receivedData(DATA_FRAME-1 downto 1)  ;
        else
            receivedData    <=  receivedData                                ;
        end if;
    else
            receivedData    <=  receivedData                                ;
    end if;
end process;

holdDataProcess : process(inClock, inReset, currentState)
-- STORE RECEIVED DATA THROUGH THE UART 
begin 
    if(inReset = '0') then
            holdData    <=  (others => '0') ;
    elsif(inClock'event AND inClock = '1') then
        if(currentState = STOP_1BIT) then
            holdData    <=  receivedData    ;
        else
            holdData    <=  holdData        ;
        end if;
    else
            holdData    <=  holdData        ;
    end if;
end process;

sampledParityBitProcess : process(inClock, inReset, currentState)
--  SAMPLE THE PARITY BIT
begin
    if(inReset = '0') then
            sampledParityBit    <=  '0'                 ;
    elsif(inClock'event AND inClock = '1') then
        if(currentState = PARITY_SAMPLE) then
            sampledParityBit    <=  inRx                ;
        else
            sampledParityBit    <=  sampledParityBit    ;
        end if;
    else
            sampledParityBit    <=  sampledParityBit    ;
    end if;
end process;
                        
parityBitProcess : process(inClock, inReset, currentState)
--  CALCULATE THE PARITY OF THE DATA
begin
    if(inReset = '0') then
        if(PARITY = "EVEN") then
                calculatedParityBit <=  '0'                                     ;
        elsif(PARITY = "ODD") then
                calculatedParityBit <=  '1'                                     ;
        else
                calculatedParityBit <=  '0'                                     ;
        end if;
    elsif(inClock'event AND inClock = '1') then
        if(currentState = START) then
            if(PARITY = "EVEN") then
                calculatedParityBit <=  '0'                                     ;
            elsif(PARITY = "ODD") then
                calculatedParityBit <=  '1'                                     ;
            else
                calculatedParityBit <=  '0'                                     ;
            end if;
        elsif(currentState = SAMPLE) then
                calculatedParityBit <=  calculatedParityBit XOR inRx            ;
        else
                calculatedParityBit <=  calculatedParityBit                     ;
        end if;
    else
                calculatedParityBit <=  calculatedParityBit                     ;
    end if;
end process;

validProcess : process(inClock, inReset, currentState, calculatedParityBit, sampledParityBit)
--  IS THE DATA VALID ?
begin
    if(inReset = '0') then
                valid   <=  '0'                                             ;
    elsif(inClock'event AND inClock = '1') then
        if(currentState = END_Rx) then
            if(PARITY = "NONE") then
                valid   <=  '1'                                             ;
            elsif(PARITY = "ODD") then
                valid   <=  NOT(calculatedParityBit XOR sampledParityBit)   ;
            elsif(PARITY = "EVEN") then
                valid   <=  NOT(calculatedParityBit XOR sampledParityBit)   ;
            else
                valid   <=  '0'                                             ;
            end if;
        else
                valid   <=  '0'                                             ;
        end if;
    else
                valid   <=  valid                                           ;
    end if;
end process;
--***********************************************************************************


--***********************************************************************************
--  OUTPUTS ASSIGNMENTS
--*********************************************************************************** 

-- SENT VALUE ON THE UART LINE
outData     <=  holdData;

--  UART IS READY TO SEND A NEW DATA
outValid    <=  valid   ;

--  ERROR DETECTED
outError    <=  '1'                                             when    (currentState = CONFIG_ERROR)   else
                '0'                                                                                     ;
--*********************************************************************************** 

end Behavioral;
