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
use IEEE.STD_LOGIC_MISC.ALL;

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
    generic ( DEPTH : integer;
              START : integer;
              INTERVAL : integer);
    PORT(
          clk : IN std_logic;
          reset : IN std_logic;
          data : IN std_logic_vector(95 downto 0);
          state : IN  STD_LOGIC_VECTOR (255 downto 0);
          currnonce : OUT std_logic_vector(31 downto 0);
          hit : OUT std_logic;
          exhausted : OUT std_logic
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

  COMPONENT bitdcm
    PORT(
          CLK_IN1 : in std_logic;
          CLK_OUT1 : out std_logic;
          LOCKED : out std_logic
        );
  END COMPONENT;

  constant DEPTH : integer := 0;
  constant NUM_MINERS : integer := 8;

  signal reset : std_logic;
  signal clk : std_logic;
  signal clk_dcmin : std_logic;
  signal clk_dcmout : std_logic;
  signal data : std_logic_vector(95 downto 0);
  signal state : std_logic_vector(255 downto 0);
  signal load : std_logic_vector(343 downto 0);
  signal loadctr : std_logic_vector(5 downto 0);
  signal loading : std_logic := '0';
  signal txdata : std_logic_vector(48 downto 0);
  signal txwidth : std_logic_vector(5 downto 0);
  signal txstrobe : std_logic;
  signal rxdata : std_logic_vector(7 downto 0);
  signal rxstrobe : std_logic;
  signal locked : std_logic;

  --Postfix 's' to indicate an array of miner signals (almost plural, but not quite)
  type nonces is array ((NUM_MINERS-1) downto 0) of std_logic_vector(31 downto 0);
  signal currnonces : nonces;
  signal hits : std_logic_vector((NUM_MINERS-1) downto 0);
  signal exhausteds : std_logic_vector((NUM_MINERS-1) downto 0);

  function process_hits(arghits : std_logic_vector; argnonces : nonces) return std_logic_vector is
    variable result : std_logic_vector(48 downto 0);
  begin
    for i in 0 to (arghits'length-1) loop
      if arghits(i) = '1' then
        result := argnonces(i)(7 downto 0) & "01" & argnonces(i)(15 downto 8) & "01" & argnonces(i)(23 downto 16) & "01" & argnonces(i)(31 downto 24) & "01000000100";
      end if;
    end loop;
    return result;
  end function;

begin


  inst_dcm : bitdcm
  port map (
             -- Clock in ports
             CLK_IN1 => clk_in,
             -- Clock out ports
             CLK_OUT1 => clk,
             -- Status and control signals
             LOCKED => locked
           );

  m: for i in 0 to (NUM_MINERS-1) generate
    Inst_miner: miner
    generic map (
                  DEPTH => DEPTH,
                  START => i,
                  INTERVAL => NUM_MINERS
                )
    port map (
               clk => clk,
               reset => reset,
               data => data,
               state => state,
               currnonce => currnonces(i),
               hit => hits(i),
               exhausted => exhausteds(i)
             );
  end generate;

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
      txdata <= "0000000000000000000000000000000000000000000000000";
      txwidth <= "000000";
      txstrobe <= '0';

      if rxstrobe = '1' then
        if loading = '1' then
          if loadctr = "101011" then
            --Finish loading
            state <= load(343 downto 88);
            data <= load(87 downto 0) & rxdata;
            txdata <= "1111111111111111111111111111111111111111000000010";
            txwidth <= "001010";
            txstrobe <= '1';
            loading <= '0';
            reset <= '0';
          else
            --Loading cycle
            load(343 downto 8) <= load(335 downto 0);
            load(7 downto 0) <= rxdata;
            loadctr <= loadctr + 1;
          end if;
        else
          if rxdata = "00000000" then
            --?
            txdata <= "1111111111111111111111111111111111111111000000000";
            txwidth <= "001010";
            txstrobe <= '1';
          elsif rxdata = "00000001" then
            --Start loading data
            loadctr <= "000000";
            loading <= '1';
            reset <= '1';
          end if;
        end if;

      elsif OR_REDUCE(hits) = '1' then
        --Found a valid response
        txdata <= process_hits(hits, currnonces);
        txwidth <= "110010";
        txstrobe <= '1';
      elsif AND_REDUCE(exhausteds) = '1' then
        --Reached the end of the search space
        txdata <= "1111111111111111111111111111111111111111000000110";
        txwidth <= "110010";
        txstrobe <= '1';
      end if;
    end if;
  end process;

end Behavioral;

