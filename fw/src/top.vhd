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
         rx     : in  STD_LOGIC;
         leds   : out STD_LOGIC_VECTOR(3 downto 0)
       );
end top;

architecture Behavioral of top is

  COMPONENT miner
    generic (
    DEPTH : integer;
    ID    : integer;
    TOTAL : integer
  );
  PORT(
        clk : IN std_logic;
        reset : IN std_logic;

        shiftindata : in std_logic;
        shiftinen   : in std_logic;

        valid_nonce : OUT std_logic_vector(31 downto 0);
        exhausted_space : out STD_LOGIC;
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

  COMPONENT bitdcm
    PORT(
          CLK_IN1 : in std_logic;
          CLK_OUT1 : out std_logic;
          LOCKED : out std_logic
        );
  END COMPONENT;

  constant DEPTH : integer := 2;

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

  signal miner_reset : std_logic;
  signal exhausted_space : std_logic_vector(1 downto 0);
  signal hit             : std_logic_vector(1 downto 0);
  type nonces is array (1 downto 0) of std_logic_vector(31 downto 0);
  signal valid_nonce    : nonces;
  signal shiftindata : std_logic;
  signal shiftinen : std_logic;
  signal shiftreg : std_logic_vector((256+96-1) downto 0);
  signal shifted : integer := 0;
  constant TOTALSHIFT : integer := 256 + 96;
  signal start_shift : std_logic;
  signal finish_shift : std_logic;

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

  --todo: turn the miners into a generate statement
  miner0: miner
  generic map (
                DEPTH => DEPTH,
                ID    => 0,
                TOTAL => 2
              )
  port map (
             clk => clk,
             reset => miner_reset,
             shiftindata => shiftindata,
             shiftinen => shiftinen,
             exhausted_space => exhausted_space(0),
             valid_nonce => valid_nonce(0),
             hit => hit(0)
           );

  --TODO: run this one in parallel testing the other half of the space (if it fits)
  miner1: miner
  generic map (
                DEPTH => DEPTH,
                ID    => 1,
                TOTAL => 2
              )
  port map (
             clk => clk,
             reset => miner_reset,
             shiftindata => shiftindata,
             shiftinen => shiftinen,
             exhausted_space => exhausted_space(1),
             valid_nonce => valid_nonce(1),
             hit => hit(1)
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

  leds(3) <= locked;

  shifting: process(clk, start_shift, finish_shift, shifted)
  begin
    if clk'event and clk = '1' then
      shiftindata <= shiftreg(0);
      if start_shift = '1' then
        miner_reset <= '1';
        shiftreg <= '0' & shiftreg((256+96-1) downto 1);
        shifted <= shifted + 1;
        shiftinen <= '1';

        --TODO: may be off by 1 here
        if shifted = (TOTALSHIFT-1) then
          miner_reset <= '0';
          shiftinen <= '0';
          finish_shift <= '1';
        end if;
      else
        shiftreg((256+96-1) downto 96) <= state;
        shiftreg(95 downto 0) <= data;

        if finish_shift = '1' then
          finish_shift <= '0';
          shifted <= 0;
        end if;
      end if;
    end if;
  end process;

  uarting: process(clk, rxstrobe, loading, hit, exhausted_space)
  begin
    if rising_edge(clk) then
      txdata <= "0000000000000000000000000000000000000000000000000";
      txwidth <= "000000";
      txstrobe <= '0';

      if start_shift = '1' and finish_shift = '1' then
        start_shift <= '0';
      end if;

      if rxstrobe = '1' then
        if loading = '1' then
          if loadctr = "101011" then
            leds(2 downto 0) <= "100";
            state <= load(343 downto 88);
            data <= load(87 downto 0) & rxdata;
            txdata <= "1111111111111111111111111111111111111111000000010";
            txwidth <= "001010";
            txstrobe <= '1';
            loading <= '0';
          else
            leds(2 downto 0) <= "101";
            load(343 downto 8) <= load(335 downto 0);
            load(7 downto 0) <= rxdata;
            loadctr <= loadctr + 1;
            start_shift <= '1';
          end if;
        else
          if rxdata = "00000000" then
            leds(2 downto 0) <= "110";
            txdata <= "1111111111111111111111111111111111111111000000000";
            txwidth <= "001010";
            txstrobe <= '1';
          elsif rxdata = "00000001" then
            leds(2 downto 0) <= "111";
            loadctr <= "000000";
            loading <= '1';
          end if;
        end if;
      elsif hit(0) = '1' then
        leds(2 downto 0) <= "010";
        txdata <= valid_nonce(0)(7 downto 0) & "01" & valid_nonce(0)(15 downto 8) & "01" & valid_nonce(0)(23 downto 16) & "01" & valid_nonce(0)(31 downto 24) & "01000000100";
        txwidth <= "110010";
        txstrobe <= '1';
      elsif hit(1) = '1' then
        leds(2 downto 0) <= "010";
        txdata <= valid_nonce(1)(7 downto 0) & "01" & valid_nonce(1)(15 downto 8) & "01" & valid_nonce(1)(23 downto 16) & "01" & valid_nonce(1)(31 downto 24) & "01000000100";
        txwidth <= "110010";
        txstrobe <= '1';
      elsif exhausted_space(0) = '1' and exhausted_space(1) = '1' then
        leds(2 downto 0) <= "011";
        txdata <= "1111111111111111111111111111111111111111000000110";
        txwidth <= "110010";
        txstrobe <= '1';
      end if;
    end if;
  end process;


end Behavioral;

