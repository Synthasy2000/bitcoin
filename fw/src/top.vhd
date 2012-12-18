----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date:    22:18:21 05/28/2011
-- Design Name:
-- Module Name:    top - Behavioral
-- Project Name:
-- Target Devices:
-- Tool versions:
-- Description:
--
-- Dependencies:
--
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity top is
  port (
         clk_in : in  STD_LOGIC;
         tx     : out STD_LOGIC;
         rx     : in  STD_LOGIC
       );
end top;

architecture Behavioral of top is

  COMPONENT miner
    generic ( DEPTH : integer );
    PORT(
          clk : IN std_logic;
          step : IN std_logic_vector(5 downto 0);
          data : IN std_logic_vector(95 downto 0);
          state : IN  STD_LOGIC_VECTOR (255 downto 0);
          nonce : IN std_logic_vector(31 downto 0);
          hit : OUT std_logic
        );
  END COMPONENT;

  COMPONENT uart
    PORT(
          clk : IN std_logic;
          rx : IN std_logic;
          txdata : IN std_logic_vector(48 downto 0);
          txwidth : IN std_logic_vector(5 downto 0);
          txstrobe : IN std_logic;
          txbusy : OUT std_logic;
          tx : OUT std_logic;
          rxdata : OUT std_logic_vector(7 downto 0);
          rxstrobe : OUT std_logic
        );
  END COMPONENT;

  COMPONENT dcm
    PORT(
          CLK_IN1 : in std_logic;
          CLK_OUT1 : out std_logic;
          LOCKED : out std_logic
        );
  END COMPONENT;

  constant DEPTH : integer := 3;

  signal clk : std_logic;
  signal clk_dcmin : std_logic;
  signal clk_dcmout : std_logic;
  signal data : std_logic_vector(95 downto 0);
  signal state : std_logic_vector(255 downto 0);
  signal nonce : std_logic_vector(31 downto 0);
  signal currnonce : std_logic_vector(31 downto 0);
  signal load : std_logic_vector(343 downto 0);
  signal loadctr : std_logic_vector(5 downto 0);
  signal loading : std_logic := '0';
  signal hit : std_logic;
  signal txdata : std_logic_vector(48 downto 0);
  signal txwidth : std_logic_vector(5 downto 0);
  signal txstrobe : std_logic;
  signal rxdata : std_logic_vector(7 downto 0);
  signal rxstrobe : std_logic;
  signal step : std_logic_vector(5 downto 0) := "000000";

begin


  currnonce <= nonce - 2 * 2 ** DEPTH;

  inst_dcm : dcm
  port map (
             -- Clock in ports
             CLK_IN1 => clk_in,
             -- Clock out ports
             CLK_OUT1 => clk,
             -- Status and control signals
             LOCKED => open
           );

  miner0: miner
  generic map ( DEPTH => DEPTH )
  port map (
             clk => clk,
             step => step,
             data => data,
             state => state,
             nonce => nonce,
             hit => hit
           );

  serial: uart
  port map (
             clk => clk,
             tx => tx,
             rx => rx,
             txdata => txdata,
             txwidth => txwidth,
             txstrobe => txstrobe,
             txbusy => open,
             rxdata => rxdata,
             rxstrobe => rxstrobe
           );

  process(clk)
  begin
    if rising_edge(clk) then
      step <= step + 1;
      if conv_integer(step) = 2 ** (6 - DEPTH) - 1 then
        step <= "000000";
        nonce <= nonce + 1;
      end if;
      txdata <= "-------------------------------------------------";
                txwidth <= "------";
                           txstrobe <= '0';
                           if rxstrobe = '1' then
                             if loading = '1' then
                               if loadctr = "101011" then
                                 state <= load(343 downto 88);
                                 data <= load(87 downto 0) & rxdata;
                                 nonce <= x"00000000";
                                 txdata <= "1111111111111111111111111111111111111111000000010";
                                 txwidth <= "001010";
                                 txstrobe <= '1';
                                 loading <= '0';
                               else
                                 load(343 downto 8) <= load(335 downto 0);
                                 load(7 downto 0) <= rxdata;
                                 loadctr <= loadctr + 1;
                               end if;
                             else
                               if rxdata = "00000000" then
                                 txdata <= "1111111111111111111111111111111111111111000000000";
                                 txwidth <= "001010";
                                 txstrobe <= '1';
                               elsif rxdata = "00000001" then
                                 loadctr <= "000000";
                                 loading <= '1';
                               end if;
                             end if;
                           elsif hit = '1' then
                             txdata <= currnonce(7 downto 0) & "01" & currnonce(15 downto 8) & "01" & currnonce(23 downto 16) & "01" & currnonce(31 downto 24) & "01000000100";
                             txwidth <= "110010";
                             txstrobe <= '1';
                           elsif nonce = x"ffffffff" and step = "000000" then
                             txdata <= "1111111111111111111111111111111111111111000000110";
                             txwidth <= "110010";
                             txstrobe <= '1';
                           end if;
              end if;
    end process;


  end Behavioral;

