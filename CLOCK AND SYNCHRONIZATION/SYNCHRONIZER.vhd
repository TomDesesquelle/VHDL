----------------------------------------------------------------------------------
-- Company:         CEA
-- Engineer:        Tom Désesquelle
-- 
-- Create Date:     09.04.2023
-- Design Name:     SYNCHRONIZER
-- Module Name:     SYNCHRONIZER - Behavioral
-- Project Name:    
-- Target Devices:  
-- Tool Versions:   VIVADO 2018.3
-- Description:     SYNCHRONIZER AND EDGES DETECTOR MODULE
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity SYNCHRONIZER is
    PORT (
        inClock     :   IN      STD_LOGIC                       ;
        inReset     :   IN      STD_LOGIC                       ;
        inData      :   IN      STD_LOGIC                       ;
        outDataSync :   OUT     STD_LOGIC                       ;
        outData_RE  :   OUT     STD_LOGIC                       ;
        outData_FE  :   OUT     STD_LOGIC                       
    );
end SYNCHRONIZER;

architecture Behavioral of SYNCHRONIZER is

--***********************************************************************************
--  SIGNAL DECLARATIONS
--***********************************************************************************

--  DATA SYNCHRONIZATION
signal      DATA_DFF_i_0        :   STD_LOGIC   ;
signal      DATA_DFF_i_1        :   STD_LOGIC   ;
signal      DATA_DFF_i_2        :   STD_LOGIC   ;

--  DATA EDGES
signal      DATA_RISING_EDGE    :   STD_LOGIC   ;
signal      DATA_FALLING_EDGE   :   STD_LOGIC   ;
--***********************************************************************************

begin

--***********************************************************************************
--  SYNCHRONIZATION AND EDGES DETECTION PROCESSES
--***********************************************************************************
DATA_DFF_0 : process(inClock, inReset, inData)
begin
    if(inReset = '0') then
        DATA_DFF_i_0    <=  '0'             ;
    elsif (inClock'event and inClock = '1') then
        DATA_DFF_i_0    <=  inData          ;
    else
        DATA_DFF_i_0    <=  DATA_DFF_i_0    ;
    end if;
end process;

DATA_DFF_1 : process(inClock, inReset, DATA_DFF_i_0)
begin
    if(inReset = '0') then
        DATA_DFF_i_1    <=  '0'             ;
    elsif (inClock'event and inClock = '1') then
        DATA_DFF_i_1    <=  DATA_DFF_i_0    ;
    else
        DATA_DFF_i_1    <=  DATA_DFF_i_1    ;
    end if;
end process;

DATA_DFF_2 : process(inClock, inReset, DATA_DFF_i_1)
begin
    if(inReset = '0') then
        DATA_DFF_i_2    <=  '0'             ;
    elsif (inClock'event and inClock = '1') then
        DATA_DFF_i_2    <=  DATA_DFF_i_1    ;
    else
        DATA_DFF_i_2    <=  DATA_DFF_i_2    ;
    end if;
end process;
--***********************************************************************************

--***********************************************************************************
--  EDGES DETECTION
--***********************************************************************************
outData_RE  <=  DATA_DFF_i_1 AND (NOT DATA_DFF_i_2) ;
outData_FE  <=  DATA_DFF_i_2 AND (NOT DATA_DFF_i_1) ;
--***********************************************************************************

--***********************************************************************************
--  DATA SYNCHRONIZATION
--***********************************************************************************
outDataSync <=  DATA_DFF_i_2                        ;
--***********************************************************************************

end Behavioral;
