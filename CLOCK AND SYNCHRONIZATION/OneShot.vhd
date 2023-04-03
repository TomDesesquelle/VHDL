----------------------------------------------------------------------------------
-- Company:         CEA
-- Engineer:        Tom Désesquelle
-- 
-- Create Date:     02.03.2021
-- Design Name:     OneShot
-- Module Name:     OneShot - Behavioral
-- Project Name:    
-- Target Devices:  
-- Tool Versions:   VIVADO 2018.3
-- Description: 	  MONOSTABLE MULTIVIBRATOR TO GENERATE A SINGLE OUTPUT PULSE, 
--					        WHEN A SUITABLE EXTERNAL TRIGGER SIGNAL IS APPLIED
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity OneShot is
    Port (  inClock     :   IN  STD_LOGIC;
            inReset     :   IN  STD_LOGIC;
            inData      :   IN  STD_LOGIC;
            inEnable    :   IN  STD_LOGIC;
            outQ_LE     :   OUT STD_LOGIC;  -- leading edge
            outQ_TE     :   OUT STD_LOGIC   -- trailing  edge
        ); 
end OneShot;


architecture Behavioral of OneShot is
    
signal  sigQout1    :   std_logic   :=  '0';
signal  sigQout1_b  :   std_logic   :=  '0';
signal  sigQout2    :   std_logic   :=  '0';
signal  sigQout2_b  :   std_logic   :=  '0';
    
begin

uut1 : entity work.dff
    Port Map(
                inReset     =>  inReset     ,
                inData      =>  inData      ,
                inClock     =>  inClock     ,
                inEnable    =>  inEnable    ,
                outQ        =>  sigQout1    ,
                outQ_b      =>  sigQout1_b
    );

uut2 : entity work.dff
    Port Map(
                inReset     =>  inReset     ,
                inData      =>  sigQout1    ,
                inClock     =>  inClock     ,
                inEnable    =>  inEnable    ,
                outQ        =>  sigQout2    ,
                outQ_b      =>  sigQout2_b
    );

outQ_LE <=  sigQout1 and (not sigQout2);
outQ_TE <=  sigQout2 and (not sigQout1);
    
end Behavioral;
