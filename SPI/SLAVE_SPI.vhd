----------------------------------------------------------------------------------
-- Company:         CEA
-- Engineer:        Tom Désesquelle
-- 
-- Create Date:     09.04.2023
-- Design Name:     SLAVE_SPI
-- Module Name:     SLAVE_SPI - Behavioral
-- Project Name:    
-- Target Devices:  
-- Tool Versions:   VIVADO 2018.3
-- Description:     RECONFIGURABLE SLAVE SERIAL PERIPHERAL INTERFACE (SPI) MODULE
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity SLAVE_SPI is
    GENERIC (
        CPOL        :           STD_LOGIC   :=  '0'             ;
        CPHA        :           STD_LOGIC   :=  '0'             ;
        MODE        :           STRING      :=  "FULL"              --  "FULL", "HALF", "SIMPLEX"
    );
    PORT (
        inClock     :   IN      STD_LOGIC                       ;
        inReset     :   IN      STD_LOGIC                       ;
        inHalf_WnR  :   IN      STD_LOGIC                       ;   --  Useful only for "HALF" DUPLEX MODE
        inData      :   IN      STD_LOGIC_VECTOR(7 DOWNTO 0)    ;
        outData     :   OUT     STD_LOGIC_VECTOR(7 DOWNTO 0)    ;
        outDone     :   OUT     STD_LOGIC                       ;
        outError    :   OUT     STD_LOGIC                       ;
        
        SCK         :   IN      STD_LOGIC                       ;
        SS          :   IN      STD_LOGIC                       ;
        MISO        :   INOUT   STD_LOGIC                       ;
        MOSI        :   IN      STD_LOGIC                       
    );
end SLAVE_SPI;

architecture Behavioral of SLAVE_SPI is
--***********************************************************************************
--  TYPE DECLARATIONS
--***********************************************************************************
TYPE    STATE      IS  (FSM_START, DATA_SAMPLE, DATA_LOAD, WAIT_SS_HIGH, SS_HIGH, ERROR)       ;
--***********************************************************************************

--***********************************************************************************
--  CONSTANT DECLARATIONS
--***********************************************************************************
constant    DATA_INDEX_MAX  :   INTEGER     :=  7               ;
--***********************************************************************************

--***********************************************************************************
--  SIGNAL DECLARATIONS
--***********************************************************************************

--  MOSI
signal      MOSI_SR         :   STD_LOGIC_VECTOR(7 DOWNTO 0)    ;

--  MISO
signal      MISO_SR         :   STD_LOGIC_VECTOR(7 DOWNTO 0)    ;
signal      MISO_i          :   STD_LOGIC                       ;

--  COUNTER
signal      currentData_i   :   INTEGER RANGE 0 TO 7            ;
signal      counterEnable   :   STD_LOGIC                       ;  

--  SYNCHRONIZATION
signal      SCK_DFF_i_0     :   STD_LOGIC                       ;
signal      SCK_DFF_i_1     :   STD_LOGIC                       ;
signal      SCK_DFF_i_2     :   STD_LOGIC                       ;
signal      SS_DFF_i_0      :   STD_LOGIC                       ;
signal      SS_DFF_i_1      :   STD_LOGIC                       ;
signal      SS_DFF_i_2      :   STD_LOGIC                       ;
signal      MOSI_DFF_i_0    :   STD_LOGIC                       ;
signal      MOSI_DFF_i_1    :   STD_LOGIC                       ;
signal      MOSI_DFF_i_2    :   STD_LOGIC                       ;
signal      MISO_DFF_i_0    :   STD_LOGIC                       ;
signal      MISO_DFF_i_1    :   STD_LOGIC                       ;
signal      MISO_DFF_i_2    :   STD_LOGIC                       ;

--  SCK EDGES
signal      SCK_RISING_EDGE :   STD_LOGIC                       ;
signal      SCK_FALLING_EDGE:   STD_LOGIC                       ;

--  ERRORS
signal      SSError         :   STD_LOGIC                       ;
signal      configError     :   STD_LOGIC                       ;

--  FSM
signal      currentState    :   STATE       :=  FSM_START       ;
signal      nextState       :   STATE       :=  FSM_START       ;
--***********************************************************************************

begin

--***********************************************************************************
--  SYNCHRONIZATION
--***********************************************************************************
SCK_DFF_0 : process(inClock, inReset, SCK)
begin
    if(inReset = '0') then
        SCK_DFF_i_0     <=  CPOL        ;
    elsif (inClock'event and inClock = '1') then
        SCK_DFF_i_0     <=  SCK         ;
    else
        SCK_DFF_i_0     <=  SCK_DFF_i_0 ;
    end if;
end process;

SCK_DFF_1 : process(inClock, inReset, SCK_DFF_i_0)
begin
    if(inReset = '0') then
        SCK_DFF_i_1     <=  CPOL        ;
    elsif (inClock'event and inClock = '1') then
        SCK_DFF_i_1     <=  SCK_DFF_i_0 ;
    else
        SCK_DFF_i_1     <=  SCK_DFF_i_1 ;
    end if;
end process;

SCK_DFF_2 : process(inClock, inReset, SCK_DFF_i_1)
begin
    if(inReset = '0') then
        SCK_DFF_i_2     <=  CPOL        ;
    elsif (inClock'event and inClock = '1') then
        SCK_DFF_i_2     <=  SCK_DFF_i_1 ;
    else
        SCK_DFF_i_2     <=  SCK_DFF_i_2 ;
    end if;
end process;

SS_DFF_0 : process(inClock, inReset, SS)
begin
    if(inReset = '0') then
        SS_DFF_i_0      <=  '1'         ;
    elsif (inClock'event and inClock = '1') then
        SS_DFF_i_0      <=  SS          ;
    else
        SS_DFF_i_0      <=  SS_DFF_i_0  ;
    end if;
end process;

SS_DFF_1 : process(inClock, inReset, SS_DFF_i_0)
begin
    if(inReset = '0') then
        SS_DFF_i_1      <=  '1'         ;
    elsif (inClock'event and inClock = '1') then
        SS_DFF_i_1      <=  SS_DFF_i_0  ;
    else
        SS_DFF_i_1      <=  SS_DFF_i_1  ;
    end if;
end process;

SS_DFF_2 : process(inClock, inReset, SS_DFF_i_1)
begin
    if(inReset = '0') then
        SS_DFF_i_2      <=  '1'         ;
    elsif (inClock'event and inClock = '1') then
        SS_DFF_i_2      <=  SS_DFF_i_1  ;
    else
        SS_DFF_i_2      <=  SS_DFF_i_2  ;
    end if;
end process;

MOSI_DFF_0 : process(inClock, inReset, MOSI)
begin
    if(inReset = '0') then
        MOSI_DFF_i_0    <=  '0'         ;
    elsif (inClock'event and inClock = '1') then
        MOSI_DFF_i_0    <=  MOSI        ;
    else
        MOSI_DFF_i_0    <=  MOSI_DFF_i_0;
    end if;
end process;

MOSI_DFF_1 : process(inClock, inReset, MOSI_DFF_i_0)
begin
    if(inReset = '0') then
        MOSI_DFF_i_1    <=  '0'         ;
    elsif (inClock'event and inClock = '1') then
        MOSI_DFF_i_1    <=  MOSI_DFF_i_0;
    else
        MOSI_DFF_i_1    <=  MOSI_DFF_i_1;
    end if;
end process;

MOSI_DFF_2 : process(inClock, inReset, MOSI_DFF_i_1)
begin
    if(inReset = '0') then
        MOSI_DFF_i_2    <=  '0'         ;
    elsif (inClock'event and inClock = '1') then
        MOSI_DFF_i_2    <=  MOSI_DFF_i_1;
    else
        MOSI_DFF_i_2    <=  MOSI_DFF_i_2;
    end if;
end process;

MISO_DFF_0 : process(inClock, inReset, MISO)
begin
    if(inReset = '0') then
            MISO_DFF_i_0    <=  '0'         ;
    elsif (inClock'event and inClock = '1') then
        if(MODE = "HALF") then
            MISO_DFF_i_0    <=  MISO        ;
        else
            MISO_DFF_i_0    <=  '0'         ;
        end if;
    else
            MISO_DFF_i_0    <=  MISO_DFF_i_0;
    end if;
end process;

MISO_DFF_1 : process(inClock, inReset, MISO_DFF_i_0)
begin
    if(inReset = '0') then
            MISO_DFF_i_1    <=  '0'         ;
    elsif (inClock'event and inClock = '1') then
        if(MODE = "HALF") then
            MISO_DFF_i_1    <=  MISO_DFF_i_0;
        else
            MISO_DFF_i_1    <=  '0'         ;
        end if;
    else
            MISO_DFF_i_1    <=  MISO_DFF_i_1;
    end if;
end process;

MISO_DFF_2 : process(inClock, inReset, MISO_DFF_i_1)
begin
    if(inReset = '0') then
            MISO_DFF_i_2    <=  '0'         ;
    elsif (inClock'event and inClock = '1') then
        if(MODE = "HALF") then
            MISO_DFF_i_2    <=  MISO_DFF_i_1;
        else
            MISO_DFF_i_2    <=  '0'         ;
        end if;
    else
            MISO_DFF_i_2    <=  MISO_DFF_i_2;
    end if;
end process;
--***********************************************************************************

--***********************************************************************************
--  EDGES DETECTION
--***********************************************************************************
SCK_RISING_EDGE     <=  (SCK_DFF_i_1 AND (NOT SCK_DFF_i_2)) OR (SS_DFF_i_2 AND (NOT SS_DFF_i_1))    when    (CPHA = '0' AND CPOL = '1')     else
                        (SCK_DFF_i_1 AND (NOT SCK_DFF_i_2)) ;

SCK_FALLING_EDGE    <=  (SCK_DFF_i_2 AND (NOT SCK_DFF_i_1)) OR (SS_DFF_i_1 AND (NOT SS_DFF_i_2))    when    (CPHA = '0' AND CPOL = '1')     else
                        (SCK_DFF_i_2 AND (NOT SCK_DFF_i_1)) ;
--***********************************************************************************

--***********************************************************************************
--  COUNTER ENABLE
--***********************************************************************************
counterEnableProcess : process(inClock, inReset, currentState, nextState)
--  ENABLE THE COUNTER ONLY ONCE IN THE DATA_LOAD STATE
begin
    if(inReset = '0') then
            counterEnable   <=  '0'             ;
    elsif(inClock'event AND inClock = '1') then
        if(currentState = DATA_SAMPLE AND nextState = DATA_LOAD) then
            counterEnable   <=  '1'             ;
        else
            counterEnable   <=  '0'             ;
        end if; 
    else
            counterEnable   <=  counterEnable   ;
    end if;
end process;
--***********************************************************************************

--***********************************************************************************
--  DATA CYCLE COUNTER
--***********************************************************************************
dataCycleCounterProcess : process(inClock, inReset, counterEnable, currentData_i)
--  COUNT THE CURRENT CYCLE OF THE DATA
begin
    if(inReset = '0' OR currentState = FSM_START) then
            currentData_i   <=  0                   ;
    elsif(inClock'event AND inClock = '1') then
        if(counterEnable = '1') then
            currentData_i   <=  currentData_i + 1   ;
        else
            currentData_i   <=  currentData_i       ;
        end if; 
    else
            currentData_i   <=  currentData_i       ;
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
        currentState    <=  FSM_START       ;
    elsif(inClock = '1' and inClock'event) then
        currentState    <=  nextState       ;
    else
        currentState    <=  currentState    ;
    end if;
end process;

fsmProcess : process(currentState, SCK_RISING_EDGE, SCK_FALLING_EDGE, SS_DFF_i_2)
--  FSM TO SWITCH BETWEEN RX & TX STATE
begin
    CASE currentState IS
                          
        when    FSM_START   =>
                                    if(CPHA = '0') then
                                        if(CPOL = '0') then
                                            if(SS_DFF_i_2 = '0') then
                                                    nextState   <=  DATA_SAMPLE ;
                                            else
                                                    nextState   <=  FSM_START   ;
                                            end if;
                                        elsif(CPOL = '1') then
                                            if(SS_DFF_i_2 = '0') then
                                                    nextState   <=  DATA_SAMPLE ;
                                            else
                                                    nextState   <=  FSM_START   ;
                                            end if;
                                        else
                                                    nextState   <=  ERROR       ;
                                        end if;
                                    elsif(CPHA = '1') then
                                        if(CPOL = '0') then
                                            if(SS_DFF_i_2 = '0' AND SCK_RISING_EDGE = '1') then
                                                    nextState   <=  DATA_SAMPLE ;
                                            else
                                                    nextState   <=  FSM_START   ;
                                            end if;
                                        elsif(CPOL = '1') then
                                            if(SS_DFF_i_2 = '0' AND SCK_FALLING_EDGE = '1') then
                                                    nextState   <=  DATA_SAMPLE ;
                                            else
                                                    nextState   <=  FSM_START   ;
                                            end if;
                                        else
                                                    nextState   <=  ERROR       ;
                                        end if;
                                    else
                                                    nextState   <=  ERROR       ;
                                    end if;
                                              
        when    DATA_SAMPLE =>
                                    if(CPHA = '0') then
                                        if(CPOL = '0') then
                                            if(SCK_RISING_EDGE = '1') then
                                                    nextState   <=  DATA_LOAD   ;
                                            else
                                                    nextState   <=  DATA_SAMPLE ;
                                            end if;
                                        elsif(CPOL = '1') then
                                            if(SCK_FALLING_EDGE = '1') then
                                                    nextState   <=  DATA_LOAD   ;
                                            else
                                                    nextState   <=  DATA_SAMPLE ;
                                            end if;
                                        else
                                                    nextState   <=  ERROR       ;
                                        end if;
                                    elsif(CPHA = '1') then
                                        if(CPOL = '0') then
                                            if(SCK_FALLING_EDGE = '1') then
                                                    nextState   <=  DATA_LOAD   ;
                                            else
                                                    nextState   <=  DATA_SAMPLE ;
                                            end if;
                                        elsif(CPOL = '1') then
                                            if(SCK_RISING_EDGE = '1') then
                                                    nextState   <=  DATA_LOAD   ;
                                            else
                                                    nextState   <=  DATA_SAMPLE ;
                                            end if;
                                        else
                                                    nextState   <=  ERROR       ;
                                        end if;
                                    else
                                                    nextState   <=  ERROR       ;
                                    end if;        
        
        when    DATA_LOAD   =>
                                    if(currentData_i = DATA_INDEX_MAX + 1) then
                                                    nextState   <=  WAIT_SS_HIGH;
                                    else
                                        if(CPHA = '0') then
                                            if(CPOL = '0') then
                                                if(SCK_FALLING_EDGE = '1') then
                                                    nextState   <=  DATA_SAMPLE ;
                                                else
                                                    nextState   <=  DATA_LOAD   ;
                                                end if;
                                            elsif(CPOL = '1') then
                                                if(SCK_RISING_EDGE = '1') then
                                                    nextState   <=  DATA_SAMPLE ;
                                                else
                                                    nextState   <=  DATA_LOAD   ;
                                                end if;
                                            else
                                                    nextState   <=  ERROR       ;
                                            end if;
                                        elsif(CPHA = '1') then
                                            if(CPOL = '0') then
                                                if(SCK_RISING_EDGE = '1') then
                                                    nextState   <=  DATA_SAMPLE ;
                                                else
                                                    nextState   <=  DATA_LOAD   ;
                                                end if;
                                            elsif(CPOL = '1') then
                                                if(SCK_FALLING_EDGE = '1') then
                                                    nextState   <=  DATA_SAMPLE ;
                                                else
                                                    nextState   <=  DATA_LOAD   ;
                                                end if;
                                            else
                                                    nextState   <=  ERROR       ;
                                            end if;
                                        else
                                                    nextState   <=  ERROR       ;
                                        end if;
                                    end if;
                                              
        when    WAIT_SS_HIGH=>
                                    if(SS_DFF_i_2 = '1') then
                                                    nextState   <=  SS_HIGH     ;
                                    else
                                                    nextState   <=  WAIT_SS_HIGH;
                                    end if;
 
        when    SS_HIGH     =>
                                                    nextState   <=  FSM_START   ;
                                            
        when    ERROR       =>
                                                    nextState   <=  ERROR       ;

        when    OTHERS      =>
                                                    nextState   <=  FSM_START   ;

    end case;
end process;
--***********************************************************************************

--***********************************************************************************
--  ERRORS
--***********************************************************************************
SSErrorProcess : process(inClock, inReset, SS_DFF_i_2, currentState)
--  DETECT IF AN ERROR OCCURS ON THE SS LINE WHEN COMMUNICATING
begin
    if(inReset = '0') then
                SSError     <=  '0'     ;
    elsif(inClock'event AND inClock = '1') then
        if(SS_DFF_i_2 = '1') then
            if(currentState = FSM_START OR currentState = WAIT_SS_HIGH OR currentState = SS_HIGH) then
                SSError     <=  '0'     ;
            else
                SSError     <=  '1'     ;
            end if;
        else
                SSError     <=  '0'     ;
        end if;
    else
                SSError     <=  SSError ;
    end if;
end process;

configErrorProcess : process(inClock, inReset, currentState)
--  DETECT IF A CONFIG ERROR OCCURS
begin
    if(inReset = '0') then
            configError <=  '0'         ;
    elsif(inClock'event AND inClock = '1') then
        if(currentState = ERROR) then
            configError <=  '1'         ;
        else
            configError <=  '0'         ;
        end if;
    else
            configError <=  configError ;
    end if;
end process;
--***********************************************************************************

--***********************************************************************************
--  MOSI
--***********************************************************************************
MOSIProcess : process(inHalf_WnR, SCK_RISING_EDGE, SCK_FALLING_EDGE, MOSI)
--  MOSI 
begin
    if(currentData_i < DATA_INDEX_MAX + 1) then
        if(MODE = "FULL") then
                if(CPHA = '0') then
                    if(CPOL = '0') then
                        if(SCK_RISING_EDGE = '1') then
                            MOSI_SR <=  MOSI_SR(6 DOWNTO 0) & MOSI  ;
                        else
                            MOSI_SR <=  MOSI_SR                     ;
                        end if;
                    elsif(CPOL = '1') then
                        if(SCK_FALLING_EDGE = '1') then
                            MOSI_SR <=  MOSI_SR(6 DOWNTO 0) & MOSI  ;
                        else
                            MOSI_SR <=  MOSI_SR                     ;
                        end if;
                    else
                            MOSI_SR <=  MOSI_SR                     ;
                    end if;
                elsif(CPHA = '1') then
                    if(CPOL = '0') then
                        if(SCK_FALLING_EDGE = '1') then
                            MOSI_SR <=  MOSI_SR(6 DOWNTO 0) & MOSI  ;
                        else
                            MOSI_SR <=  MOSI_SR                     ;
                        end if;
                    elsif(CPOL = '1') then
                        if(SCK_RISING_EDGE = '1') then
                            MOSI_SR <=  MOSI_SR(6 DOWNTO 0) & MOSI  ;
                        else
                            MOSI_SR <=  MOSI_SR                     ;
                        end if;
                    else
                            MOSI_SR <=  MOSI_SR                     ;
                    end if;
                else
                            MOSI_SR <=  MOSI_SR                     ;
                end if;
        elsif(MODE = "HALF") then
            if(inHalf_WnR = '0') then
                if(CPHA = '0') then
                    if(CPOL = '0') then
                        if(SCK_RISING_EDGE = '1') then
                            MOSI_SR <=  MOSI_SR(6 DOWNTO 0) & MOSI  ;
                        else
                            MOSI_SR <=  MOSI_SR                     ;
                        end if;
                    elsif(CPOL = '1') then
                        if(SCK_FALLING_EDGE = '1') then
                            MOSI_SR <=  MOSI_SR(6 DOWNTO 0) & MOSI  ;
                        else
                            MOSI_SR <=  MOSI_SR                     ;
                        end if;
                    else
                            MOSI_SR <=  MOSI_SR                     ;
                    end if;
                elsif(CPHA = '1') then
                    if(CPOL = '0') then
                        if(SCK_FALLING_EDGE = '1') then
                            MOSI_SR <=  MOSI_SR(6 DOWNTO 0) & MOSI  ;
                        else
                            MOSI_SR <=  MOSI_SR                     ;
                        end if;
                    elsif(CPOL = '1') then
                        if(SCK_RISING_EDGE = '1') then
                            MOSI_SR <=  MOSI_SR(6 DOWNTO 0) & MOSI  ;
                        else
                            MOSI_SR <=  MOSI_SR                     ;
                        end if;
                    else
                            MOSI_SR <=  MOSI_SR                     ;
                    end if;
                else
                            MOSI_SR <=  MOSI_SR                     ;
                end if;
            else
                            MOSI_SR <=  MOSI_SR                     ;
            end if;
        elsif(MODE = "SIMPLEX") then
                if(CPHA = '0') then
                    if(CPOL = '0') then
                        if(SCK_RISING_EDGE = '1') then
                            MOSI_SR <=  MOSI_SR(6 DOWNTO 0) & MOSI  ;
                        else
                            MOSI_SR <=  MOSI_SR                     ;
                        end if;
                    elsif(CPOL = '1') then
                        if(SCK_FALLING_EDGE = '1') then
                            MOSI_SR <=  MOSI_SR(6 DOWNTO 0) & MOSI  ;
                        else
                            MOSI_SR <=  MOSI_SR                     ;
                        end if;
                    else
                            MOSI_SR <=  MOSI_SR                     ;
                    end if;
                elsif(CPHA = '1') then
                    if(CPOL = '0') then
                        if(SCK_FALLING_EDGE = '1') then
                            MOSI_SR <=  MOSI_SR(6 DOWNTO 0) & MOSI  ;
                        else
                            MOSI_SR <=  MOSI_SR                     ;
                        end if;
                    elsif(CPOL = '1') then
                        if(SCK_RISING_EDGE = '1') then
                            MOSI_SR <=  MOSI_SR(6 DOWNTO 0) & MOSI  ;
                        else
                            MOSI_SR <=  MOSI_SR                     ;
                        end if;
                    else
                            MOSI_SR <=  MOSI_SR                     ;
                    end if;
                else
                            MOSI_SR <=  MOSI_SR                     ;
                end if;
        else
                            MOSI_SR <=  MOSI_SR                     ;
        end if;
    else
                            MOSI_SR <=  MOSI_SR                     ;
    end if;
end process;
--***********************************************************************************

--***********************************************************************************
--  MISO
--***********************************************************************************
MISODataProcess : process(inClock, inReset, currentState)
--  STORE DATA TO SEND
begin
    if(inReset = '0') then
            MISO_SR     <=  (others => '0') ;
    elsif(inClock'event AND inClock = '1') then
        if(currentState = FSM_START) then
            MISO_SR     <=  inData          ;
        else
            MISO_SR     <=  MISO_SR         ;
        end if;
    else
            MISO_SR     <=  MISO_SR         ;
    end if;
end process;

MISOProcess : process(inHalf_WnR, SCK_RISING_EDGE, SCK_FALLING_EDGE)
--  MISO 
begin
    if(currentData_i < DATA_INDEX_MAX + 1) then
        if(MODE = "FULL") then
                if(CPHA = '0') then
                    if(CPOL = '0') then
                        if(SCK_FALLING_EDGE = '1') then
                            MISO_i  <=  MISO_SR(7-currentData_i)    ;
                        else
                            MISO_i  <=  MISO_i                      ;
                        end if;
                    elsif(CPOL = '1') then
                        if(SCK_RISING_EDGE = '1') then
                            MISO_i  <=  MISO_SR(7-currentData_i)    ;
                        else
                            MISO_i  <=  MISO_i                      ;
                        end if;
                    else
                            MISO_i  <=  MISO_i                      ;
                    end if;
                elsif(CPHA = '1') then
                    if(CPOL = '0') then
                        if(SCK_RISING_EDGE = '1') then
                            MISO_i  <=  MISO_SR(7-currentData_i)    ;
                        else
                            MISO_i  <=  MISO_i                      ;
                        end if;
                    elsif(CPOL = '1') then
                        if(SCK_FALLING_EDGE = '1') then
                            MISO_i  <=  MISO_SR(7-currentData_i)    ;
                        else
                            MISO_i  <=  MISO_i                      ;
                        end if;
                    else
                            MISO_i  <=  MISO_i                      ;
                    end if;
                else
                            MISO_i  <=  MISO_i                      ;
                end if;
        elsif(MODE = "HALF") then
            if(inHalf_WnR = '1') then
                if(CPHA = '0') then
                    if(CPOL = '0') then
                        if(SCK_FALLING_EDGE = '1') then
                            MISO_i  <=  MISO_SR(7-currentData_i)    ;
                        else
                            MISO_i  <=  MISO_i                      ;
                        end if;
                    elsif(CPOL = '1') then
                        if(SCK_RISING_EDGE = '1') then
                            MISO_i  <=  MISO_SR(7-currentData_i)    ;
                        else
                            MISO_i  <=  MISO_i                      ;
                        end if;
                    else
                            MISO_i  <=  MISO_i                      ;
                    end if;
                elsif(CPHA = '1') then
                    if(CPOL = '0') then
                        if(SCK_RISING_EDGE = '1') then
                            MISO_i  <=  MISO_SR(7-currentData_i)    ;
                        else
                            MISO_i  <=  MISO_i                      ;
                        end if;
                    elsif(CPOL = '1') then
                        if(SCK_FALLING_EDGE = '1') then
                            MISO_i  <=  MISO_SR(7-currentData_i)    ;
                        else
                            MISO_i  <=  MISO_i                      ;
                        end if;
                    else
                            MISO_i  <=  MISO_i                      ;
                    end if;
                else
                            MISO_i  <=  MISO_i                      ;
                end if;
            else
                            MISO_i  <=  'Z'                         ;
            end if;
        elsif(MODE = "SIMPLEX") then
                            MISO_i  <=  'Z'                         ;
        else
                            MISO_i  <=  MISO_i                      ;
        end if;
    else
                            MISO_i  <=  MISO_i                      ;
    end if;
end process;
--***********************************************************************************

--***********************************************************************************
--  OUTPUTS ASSIGNMENTS
--***********************************************************************************
MISO        <=  MISO_i  ;

outData     <=  MOSI_SR ;

outDone     <=  '1'     when    (currentState = SS_HIGH)    else    '0' ;

outError    <=  SSError ;
--***********************************************************************************
end Behavioral;
