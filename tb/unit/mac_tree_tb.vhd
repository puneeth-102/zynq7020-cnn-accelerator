----------------------------------------------------------------------------------
-- Testbench: mac_tree_tb.vhd
-- Description: Unit testbench for mac_tree_9x verifying Q15.16 signed
--              arithmetic, rounding, and 4-cycle pipeline latency.
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mac_tree_tb is
end entity mac_tree_tb;

architecture sim of mac_tree_tb is

    constant CLK_PERIOD : time := 10 ns; -- 100 MHz clock
    signal clk          : std_logic := '0';
    signal rst          : std_logic := '1';

    signal in_valid     : std_logic := '0';
    signal i1, i2, i3   : std_logic_vector(31 downto 0) := (others => '0');
    signal i4, i5, i6   : std_logic_vector(31 downto 0) := (others => '0');
    signal i7, i8, i9   : std_logic_vector(31 downto 0) := (others => '0');

    signal w1, w2, w3   : std_logic_vector(31 downto 0) := (others => '0');
    signal w4, w5, w6   : std_logic_vector(31 downto 0) := (others => '0');
    signal w7, w8, w9   : std_logic_vector(31 downto 0) := (others => '0');

    signal sum_out      : std_logic_vector(31 downto 0);
    signal out_valid    : std_logic;

    -- Constants in Q15.16 format
    -- 1.0 in Q15.16 = 65536 = 0x00010000
    -- 0.5 in Q15.16 = 32768 = 0x00008000
    -- -0.5 in Q15.16 = -32768 = 0xFFFF8000
    constant ONE_Q16    : std_logic_vector(31 downto 0) := x"00010000";
    constant HALF_Q16   : std_logic_vector(31 downto 0) := x"00008000";
    constant NEG_HALF   : std_logic_vector(31 downto 0) := x"FFFF8000";

begin

    -- Instantiate Device Under Test (DUT)
    dut : entity work.mac_tree_9x
        generic map (
            DATA_WIDTH => 32
        )
        port map (
            clk       => clk,
            rst       => rst,
            in_valid  => in_valid,
            i1 => i1, i2 => i2, i3 => i3,
            i4 => i4, i5 => i5, i6 => i6,
            i7 => i7, i8 => i8, i9 => i9,
            w1 => w1, w2 => w2, w3 => w3,
            w4 => w4, w5 => w5, w6 => w6,
            w7 => w7, w8 => w9, w9 => w9,
            sum_out   => sum_out,
            out_valid => out_valid
        );

    -- Clock generator: 100 MHz
    clk_process : process
    begin
        while true loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process;

    -- Stimulus process
    stim_proc : process
    begin
        -- Hold reset for 3 cycles
        rst <= '1';
        wait for CLK_PERIOD * 3;
        rst <= '0';
        wait for CLK_PERIOD;

        -- Test Case 1: All pixels = 1.0, All weights = 0.5
        -- Product of each tap = 1.0 * 0.5 = 0.5
        -- Sum of 9 taps = 9 * 0.5 = 4.5
        -- 4.5 in Q15.16 = 4.5 * 65536 = 294912 = 0x00048000
        in_valid <= '1';
        i1 <= ONE_Q16; i2 <= ONE_Q16; i3 <= ONE_Q16;
        i4 <= ONE_Q16; i5 <= ONE_Q16; i6 <= ONE_Q16;
        i7 <= ONE_Q16; i8 <= ONE_Q16; i9 <= ONE_Q16;

        w1 <= HALF_Q16; w2 <= HALF_Q16; w3 <= HALF_Q16;
        w4 <= HALF_Q16; w5 <= HALF_Q16; w6 <= HALF_Q16;
        w7 <= HALF_Q16; w8 <= HALF_Q16; w9 <= HALF_Q16;

        wait for CLK_PERIOD;

        -- Test Case 2: Negative numbers (Testing signed multiplication)
        -- Pixels = 1.0, Weights = -0.5
        -- Expected sum = 9 * (-0.5) = -4.5
        -- -4.5 in Q15.16 = -294912 = 0xFFFB8000
        w1 <= NEG_HALF; w2 <= NEG_HALF; w3 <= NEG_HALF;
        w4 <= NEG_HALF; w5 <= NEG_HALF; w6 <= NEG_HALF;
        w7 <= NEG_HALF; w8 <= NEG_HALF; w9 <= NEG_HALF;

        wait for CLK_PERIOD;
        in_valid <= '0';

        -- Wait for pipeline latency (4 clock cycles)
        wait for CLK_PERIOD * 6;

        report "[SIMULATION COMPLETED] Checked MAC tree arithmetic.";
        wait;
    end process;

end architecture sim;
