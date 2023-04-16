----------------------------------------------------------------------------------
-- Company:         CEA
-- Engineer:        Tom Désesquelle
-- 
-- Create Date:     09.04.2023
-- Design Name:     MASTER_SPI
-- Module Name:     MASTER_SPI - Behavioral
-- Project Name:    
-- Target Devices:  
-- Tool Versions:   VIVADO 2018.3
-- Description: 	  RECONFIGURABLE MASTER SERIAL PERIPHERAL INTERFACE (SPI) MODULE
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity MASTER_SPI is
    GENERIC (
        CPOL        :           STD_LOGIC   :=  '0'                     ;
        CPHA        :           STD_LOGIC   :=  '0'                     ;
        MODE        :           STRING      :=  "FULL"                  ;   --  "FULL", "HALF", "SIMPLEX"
        N           :           POSITIVE    :=  2                            
    );
    PORT (
        inClock     :   IN      STD_LOGIC                               ;
        inReset     :   IN      STD_LOGIC                               ;
        inEnable    :   IN      STD_LOGIC                               ;
        inAddr      :   IN      STD_LOGIC_VECTOR(N-1 DOWNTO 0)          ;
        inHalf_WnR  :   IN      STD_LOGIC                               ;   --  Useful only for "HALF" DUPLEX MODE
        inData      :   IN      STD_LOGIC_VECTOR(7 DOWNTO 0)            ;
        outData     :   OUT     STD_LOGIC_VECTOR(7 DOWNTO 0)            ;
        outBusy     :   OUT     STD_LOGIC                               ;
--        outError    :   OUT     STD_LOGIC                               ;
        
        SCK         :   OUT     STD_LOGIC                               ;
        SS          :   OUT     STD_LOGIC_VECTOR(N-1 DOWNTO 0)          ;
        MISO        :   IN      STD_LOGIC                               ;
        MOSI        :   INOUT   STD_LOGIC                       
    );
end MASTER_SPI;

architecture Behavioral of MASTER_SPI is
--***********************************************************************************
--  TYPE DECLARATIONS
--***********************************************************************************
TYPE    STATE      IS  (FSM_START, SS_LOW, DATA_PROCESSING, SS_HIGH)   ;
--***********************************************************************************

--***********************************************************************************
--  CONSTANT DECLARATIONS
--***********************************************************************************
constant    DATA            :   INTEGER     :=  8                       ;
constant    HALF_PERIOD     :   INTEGER     :=  5                       ;
constant    EDGES           :   INTEGER     :=  2*DATA                  ;
--***********************************************************************************

--***********************************************************************************
--  SIGNAL DECLARATIONS
--***********************************************************************************

--  SCK
signal      SCK_i           :   STD_LOGIC_VECTOR(9 DOWNTO 0)            ;

--  SS
signal      SS_i            :   STD_LOGIC_VECTOR(N-1 DOWNTO 0)          ;

--  MOSI
signal      MOSI_SR         :   STD_LOGIC_VECTOR(7 DOWNTO 0)            ;

--  MISO
signal      MISO_SR         :   STD_LOGIC_VECTOR(7 DOWNTO 0)            ;

--  EDGES
signal      SCK_RISING_EDGE :   STD_LOGIC                               ;
signal      SCK_FALLING_EDGE:   STD_LOGIC                               ;

--  COUNTERS
signal      dataCount       :   INTEGER RANGE 0 TO DATA - 1             ;

--  ERROR

--  DEBUG
signal      processing      :   INTEGER                                 ;

--  FSM
signal      currentState    :   STATE       :=  FSM_START               ;
signal      nextState       :   STATE       :=  FSM_START               ;
--***********************************************************************************

begin

--***********************************************************************************
--  PROCESSING TIME
--***********************************************************************************
processingProcess : process(inClock, inReset, currentState)
--  
begin
    if(inReset = '0') then 
            processing  <=  0               ;
    elsif(inClock'event AND inClock = '1') then
        if(currentState = FSM_START OR currentState = SS_HIGH) then
            processing  <=  0               ;
        else
            processing  <=  processing + 1  ;
        end if;
    else
            processing  <=  processing      ;
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

fsmProcess : process(currentState, inEnable, processing)
--  FSM TO
begin
    CASE currentState IS
                          
        when    FSM_START           =>
                                            if(inEnable = '1') then
                                                nextState   <=  SS_LOW          ;
                                            else
                                                nextState   <=  FSM_START       ;
                                            end if;

        when    SS_LOW              =>
                                                nextState   <=  DATA_PROCESSING ;
                                                
        when    DATA_PROCESSING     =>
                                            if(processing = (EDGES+1)*HALF_PERIOD - 2) then
                                                nextState   <=  SS_HIGH         ;
                                            else
                                                nextState   <=  DATA_PROCESSING ;
                                            end if;
                                                                                          
        when    SS_HIGH             =>
                                                nextState   <=  FSM_START       ;

        when    OTHERS              =>
                                                nextState   <=  FSM_START       ;

    end case;
end process;
--***********************************************************************************

--***********************************************************************************
--  EDGES DETECTION
--***********************************************************************************
SCK_RISING_EDGE     <=  '0'     when    (currentState = FSM_START)              else
                        '0'     when    (currentState = SS_LOW)                 else
                        '1'     when    (SCK_i(9) = '1' AND SCK_i(0) = '0')     else
                        '0'                                                     ;

SCK_FALLING_EDGE    <=  '0'     when    (currentState = FSM_START)              else
                        '0'     when    (currentState = SS_LOW)                 else
                        '1'     when    (SCK_i(9) = '0' AND SCK_i(0) = '1')     else
                        '0'                                                     ;
--***********************************************************************************

--***********************************************************************************
--  SCK
--***********************************************************************************                          
shiftRegisterProcess : process(inClock, inReset, currentState, SCK_i)
--  SHIFT DATA
begin
    if(inReset = '0') then
            SCK_i(9 DOWNTO 5)   <=  (others => CPOL)                ;
            SCK_i(4 DOWNTO 0)   <=  (others => NOT(CPOL))           ;
    elsif(inClock'event AND inClock = '1') then
        if(currentState = DATA_PROCESSING OR currentState = SS_LOW) then
            SCK_i               <=  SCK_i(8 DOWNTO 0) & SCK_i(9)    ;
        else
            SCK_i(9 DOWNTO 5)   <=  (others => CPOL)                ;
            SCK_i(4 DOWNTO 0)   <=  (others => NOT(CPOL))           ;
--            SCK_i               <=  SCK_i                           ;
        end if;
    else
            SCK_i               <=  SCK_i                           ;
    end if;
end process;
--***********************************************************************************

--***********************************************************************************
--  SS
--***********************************************************************************          
SS_i    <=  (others => '1')     when    (currentState = FSM_START)  else
            NOT(inAddr)         when    (currentState = SS_LOW)     else
            (others => '1')     when    (currentState = SS_HIGH)    else
            SS_i                                                    ;
--***********************************************************************************

--***********************************************************************************
--  MOSI
--***********************************************************************************
MOSIProcess : process(inClock, inReset, SCK_RISING_EDGE, SCK_FALLING_EDGE, currentState, inHalf_WnR)
--  MOSI
begin
    if(inReset = '0') then
                                MOSI_SR     <=  (others => '0') ;
    elsif(inClock'event AND inClock = '1') then
        if(currentState = FSM_START) then
                                MOSI_SR     <=  inData          ;
        else
            if(MODE = "FULL") then
                    if(CPHA = '0') then
                        if(CPOL = '0') then
                            if(SCK_FALLING_EDGE = '1') then
                                MOSI_SR <=  MOSI_SR(6 DOWNTO 0) & MOSI_SR(7)    ;
                            else
                                MOSI_SR <=  MOSI_SR                             ;
                            end if;
                        elsif(CPOL = '1') then
                            if(SCK_RISING_EDGE = '1') then
                                MOSI_SR <=  MOSI_SR(6 DOWNTO 0) & MOSI_SR(7)    ;
                            else
                                MOSI_SR <=  MOSI_SR                             ;
                            end if;
                        else
                                MOSI_SR <=  (others => 'Z')                     ;
                        end if;
                    elsif(CPHA = '1') then
                        if(CPOL = '0') then
                            if(SCK_RISING_EDGE = '1') then
                                MOSI_SR <=  MOSI_SR(6 DOWNTO 0) & MOSI_SR(7)    ;
                            else
                                MOSI_SR <=  MOSI_SR                             ;
                            end if;
                        elsif(CPOL = '1') then
                            if(SCK_FALLING_EDGE = '1') then
                                MOSI_SR <=  MOSI_SR(6 DOWNTO 0) & MOSI_SR(7)    ;
                            else
                                MOSI_SR <=  MOSI_SR                             ;
                            end if;
                        else
                                MOSI_SR <=  (others => 'Z')                     ;
                        end if;            
                    else
                                MOSI_SR <=  (others => 'Z')                     ;
                    end if;
            elsif(MODE = "HALF") then
                if(inHalf_WnR = '1') then
                    if(CPHA = '0') then
                        if(CPOL = '0') then
                            if(SCK_FALLING_EDGE = '1') then
                                MOSI_SR <=  MOSI_SR(6 DOWNTO 0) & MOSI_SR(7)    ;
                            else
                                MOSI_SR <=  MOSI_SR                             ;
                            end if;
                        elsif(CPOL = '1') then
                            if(SCK_RISING_EDGE = '1') then
                                MOSI_SR <=  MOSI_SR(6 DOWNTO 0) & MOSI_SR(7)    ;
                            else
                                MOSI_SR <=  MOSI_SR                             ;
                            end if;
                        else
                                MOSI_SR <=  (others => 'Z')                     ;
                        end if;
                    elsif(CPHA = '1') then
                        if(CPOL = '0') then
                            if(SCK_RISING_EDGE = '1') then
                                MOSI_SR <=  MOSI_SR(6 DOWNTO 0) & MOSI_SR(7)    ;
                            else
                                MOSI_SR <=  MOSI_SR                             ;
                            end if;
                        elsif(CPOL = '1') then
                            if(SCK_FALLING_EDGE = '1') then
                                MOSI_SR <=  MOSI_SR(6 DOWNTO 0) & MOSI_SR(7)    ;
                            else
                                MOSI_SR <=  MOSI_SR                             ;
                            end if;
                        else
                                MOSI_SR <=  (others => 'Z')                     ;
                        end if;            
                    else
                                MOSI_SR <=  (others => 'Z')                     ;
                    end if;            
                else
                                MOSI_SR <=  (others => 'Z')                     ;
                end if;
            elsif(MODE = "SIMPLEX") then
                    if(CPHA = '0') then
                        if(CPOL = '0') then
                            if(SCK_FALLING_EDGE = '1') then
                                MOSI_SR <=  MOSI_SR(6 DOWNTO 0) & MOSI_SR(7)    ;
                            else
                                MOSI_SR <=  MOSI_SR                             ;
                            end if;
                        elsif(CPOL = '1') then
                            if(SCK_RISING_EDGE = '1') then
                                MOSI_SR <=  MOSI_SR(6 DOWNTO 0) & MOSI_SR(7)    ;
                            else
                                MOSI_SR <=  MOSI_SR                             ;
                            end if;
                        else
                                MOSI_SR <=  (others => 'Z')                     ;
                        end if;
                    elsif(CPHA = '1') then
                        if(CPOL = '0') then
                            if(SCK_RISING_EDGE = '1') then
                                MOSI_SR <=  MOSI_SR(6 DOWNTO 0) & MOSI_SR(7)    ;
                            else
                                MOSI_SR <=  MOSI_SR                             ;
                            end if;
                        elsif(CPOL = '1') then
                            if(SCK_FALLING_EDGE = '1') then
                                MOSI_SR <=  MOSI_SR(6 DOWNTO 0) & MOSI_SR(7)    ;
                            else
                                MOSI_SR <=  MOSI_SR                             ;
                            end if;
                        else
                                MOSI_SR <=  (others => 'Z')                     ;
                        end if;            
                    else
                                MOSI_SR <=  (others => 'Z')                     ;
                    end if;        
            else
                    MOSI_SR <=  (others => 'Z') ;
            end if;
        end if;
    end if;
end process;
--***********************************************************************************

--***********************************************************************************
--  MISO
--***********************************************************************************
MISOProcess : process(SCK_RISING_EDGE, SCK_FALLING_EDGE, inHalf_WnR, MISO)
--  MISO
begin
    if(MODE = "FULL") then
            if(CPHA = '0') then
                if(CPOL = '0') then
                    if(SCK_RISING_EDGE = '1') then
                        MISO_SR <=  MISO_SR(6 DOWNTO 0) & MISO  ;
                    else
                        MISO_SR <=  MISO_SR                     ;
                    end if;
                elsif(CPOL = '1') then
                    if(SCK_FALLING_EDGE = '1') then
                        MISO_SR <=  MISO_SR(6 DOWNTO 0) & MISO  ;
                    else
                        MISO_SR <=  MISO_SR                     ;
                    end if;
                else
                        MISO_SR <=  MISO_SR                     ;
                end if;
            elsif(CPHA = '1') then
                if(CPOL = '0') then
                    if(SCK_FALLING_EDGE = '1') then
                        MISO_SR <=  MISO_SR(6 DOWNTO 0) & MISO  ;
                    else
                        MISO_SR <=  MISO_SR                     ;
                    end if;
                elsif(CPOL = '1') then
                    if(SCK_RISING_EDGE = '1') then
                        MISO_SR <=  MISO_SR(6 DOWNTO 0) & MISO  ;
                    else
                        MISO_SR <=  MISO_SR                     ;
                    end if;
                else
                        MISO_SR <=  MISO_SR                     ;
                end if;            
            else
                        MISO_SR <=  MISO_SR                     ;
            end if;
    elsif(MODE = "HALF") then
                        MISO_SR <=  MISO_SR                     ;
    elsif(MODE = "SIMPLEX") then
                        MISO_SR <=  MISO_SR                     ;
    else
                        MISO_SR <=  MISO_SR                     ;
    end if;
end process;
--***********************************************************************************

--***********************************************************************************
--  OUTPUTS ASSIGNMENTS
--***********************************************************************************
SS      <=  SS_i        ;
SCK     <=  SCK_i(9)    ;
MOSI    <=  MOSI_SR(7)  when    (currentState = SS_LOW)             else
            MOSI_SR(7)  when    (currentState = DATA_PROCESSING)    else
            'Z'                                                     ;
outData <=  MISO_SR     ;
outBusy <=  '1'         when    (currentState = SS_LOW)             else
            '1'         when    (currentState = DATA_PROCESSING)    else
            '1'         when    (currentState = SS_HIGH)            else
            '0'                                                     ;
--***********************************************************************************

end Behavioral;
