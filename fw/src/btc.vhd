library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_unsigned.all;

package btc is
  constant WIDTH : integer := 8;
  type slv32 is array (0 to (WIDTH-1)) of std_logic_vector(31 downto 0);

  function or_slv(v : std_logic_vector) return std_logic;
  function nonces_exhausted(n : slv32) return std_logic;
end btc;

package body btc is

  function or_slv(v : std_logic_vector) return std_logic is
    variable ret : std_logic := '0';
  begin
    for i in v'range loop
      ret := ret OR v(i);
    end loop;
    return ret;
  end or_slv;

  function nonces_exhausted(n : slv32) return std_logic is
    variable ret : std_logic := '0';
    variable s   : std_logic := '0';
  begin
    for i in n'range loop
      s   := '1' when n(i) = (n'range=>'1') else '0';
      ret := ret OR s;
    end loop;
    return ret;
  end nonces_exhausted;

end btc;
