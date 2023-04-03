----------------------------------------------------------------------------------
-- Company:         CEA
-- Engineer:        Tom Désesquelle
-- 
-- Create Date:     02.03.2021
-- Design Name:     DFF
-- Module Name:     DFF - Behavioral
-- Project Name:    
-- Target Devices:  
-- Tool Versions:   VIVADO 2018.3
-- Description: 	  D FLIP-FLOP WITH CLOCK ENABLE AND ASYNCHRONOUS CLEAR
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity DFF is
    Port (  inClock     :   IN  STD_LOGIC;
            inReset     :   IN  STD_LOGIC;
            inData      :   IN  STD_LOGIC;
            inEnable    :   IN  STD_LOGIC;
            outQ        :   OUT STD_LOGIC;
            outQ_b      :   OUT STD_LOGIC
        );
end dff;


architecture Behavioral of DFF is

signal  s_qout  :   std_logic   :=  '0';

begin
    
DFF : process(inClock, inReset, inEnable)
begin
    if(inReset = '0') then
            s_qout  <=  '0';
    elsif (inClock'event and inClock = '1') then
        if(inEnable = '1') then
            s_qout  <=  inData;
        else
            s_qout  <=  s_qout;
        end if;
    end if;
end process;

outQ    <=  s_qout;
outQ_b  <=  NOT(s_qout);

end Behavioral;
