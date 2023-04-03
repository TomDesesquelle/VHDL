----------------------------------------------------------------------------------
-- Company:         CEA
-- Engineer:        Tom Désesquelle
-- 
-- Create Date:     15.03.2021
-- Design Name:     DFF_GENERIC
-- Module Name:     DFF_GENERIC - Behavioral
-- Project Name:    
-- Target Devices:  
-- Tool Versions:   VIVADO 2018.3
-- Description: 	  MULIPLE D FLIP-FLOPS WITH CLOCK ENABLE AND ASYNCHRONOUS CLEAR
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity DFF_GENERIC is
    GENERIC (
        N           :   POSITIVE    :=  8   
    );
    PORT (
        inClock     :   IN      STD_LOGIC                       ;
        inReset     :   IN      STD_LOGIC                       ;
        inEnable    :   IN      STD_LOGIC                       ;
        inData      :   IN      STD_LOGIC_VECTOR(N-1 DOWNTO 0)  ;
        outData     :   OUT     STD_LOGIC_VECTOR(N-1 DOWNTO 0)  ;
        outnData    :   OUT     STD_LOGIC_VECTOR(N-1 DOWNTO 0)  
    );
end DFF_GENERIC;

architecture Behavioral of DFF_GENERIC is

--***********************************************************************************
--  SIGNAL DECLARATIONS
--***********************************************************************************
signal  data    :   STD_LOGIC_VECTOR(N-1 DOWNTO 0)  :=  (others => '0') ;
--***********************************************************************************

begin

--***********************************************************************************
--  BEHAVIOUR
--***********************************************************************************
dataProcess : process(inClock, inReset, inEnable, inData)
--  PIPELINE
begin
    if(inReset = '0') then
            data    <=  (others => '0') ;
    elsif(inClock'event AND inClock = '1') then
        if(inEnable = '1') then
            data    <=  inData          ;
        else
            data    <=  data            ;
        end if;
    else
            data    <=  data            ;
    end if;
end process;
--***********************************************************************************


--***********************************************************************************
--  OUTPUTS ASSIGNMENTS
--***********************************************************************************
outData     <=  data        ;
outnData    <=  NOT(data)   ;
--***********************************************************************************
end Behavioral;
