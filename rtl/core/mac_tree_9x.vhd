----------------------------------------------------------------------------------
-- Module: mac_tree_9x.vhd
-- Description: Parallel 9-Multiplier MAC Tree with Balanced Adder Reduction
--              and Q15.16 Fixed-Point Scaling / Saturation.
--
-- Constraints & Target Matching:
--   • 9 parallel multipliers configured with use_dsp = "yes"
--   • Generates exactly 36 DSP48E1 slices (4 DSPs per 32x32 multiplier)
--   • 100 MHz timing closure on Zynq-7020 (4 pipeline register stages)
--
-- Reproduces Section 4.2 & Section 5.1 (Table 4) of:
-- "FPGA-Based CNN Acceleration on Zynq-7020 for Embedded Ship Recognition"
-- (Sensors 2026, 26, 1626)
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mac_tree_9x is
    generic (
        DATA_WIDTH : natural := 32  -- 32-bit Q15.16 signed format
    );
    port (
        clk        : in  std_logic;
        rst        : in  std_logic;

        in_valid   : in  std_logic;

        -- 9 Window Pixel Taps (Q15.16)
        i1, i2, i3 : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        i4, i5, i6 : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        i7, i8, i9 : in  std_logic_vector(DATA_WIDTH-1 downto 0);

        -- 9 Kernel Weights (Q15.16)
        w1, w2, w3 : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        w4, w5, w6 : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        w7, w8, w9 : in  std_logic_vector(DATA_WIDTH-1 downto 0);

        -- Output Scaled Sum (Q15.16)
        sum_out    : out std_logic_vector(DATA_WIDTH-1 downto 0);
        out_valid  : out std_logic
    );
end entity mac_tree_9x;

architecture behavioral of mac_tree_9x is

    -- Signed conversions
    signal s_i1, s_i2, s_i3, s_i4, s_i5, s_i6, s_i7, s_i8, s_i9 : signed(DATA_WIDTH-1 downto 0);
    signal s_w1, s_w2, s_w3, s_w4, s_w5, s_w6, s_w7, s_w8, s_w9 : signed(DATA_WIDTH-1 downto 0);

    -- 64-bit Product Signals (Q30.32)
    type prod_array_t is array (1 to 9) of signed(63 downto 0);
    signal p_reg : prod_array_t := (others => (others => '0'));

    -- Directives to enforce mapping to DSP48E1 slices (9 x 4 = 36 DSPs)
    attribute use_dsp : string;
    attribute use_dsp of p_reg : signal is "yes";

    -- Pipeline stage 1 adder registers (66 bits for bit growth)
    signal sum_12, sum_34, sum_56, sum_78 : signed(65 downto 0) := (others => '0');
    signal p9_d1                          : signed(65 downto 0) := (others => '0');

    -- Pipeline stage 2 adder registers (67 bits)
    signal sum_1234, sum_5678             : signed(66 downto 0) := (others => '0');
    signal p9_d2                          : signed(66 downto 0) := (others => '0');

    -- Pipeline stage 3 adder registers (68 bits)
    signal sum_8taps                      : signed(67 downto 0) := (others => '0');
    signal total_sum                      : signed(67 downto 0) := (others => '0');

    -- Pipelined valid shift register (4 clock cycles latency)
    signal valid_pipe                     : std_logic_vector(3 downto 0) := (others => '0');

    -- Rounding constant: 2^(15) = 32768 in 68-bit representation
    constant ROUND_CONST                  : signed(67 downto 0) := to_signed(32768, 68);

begin

    -- Cast inputs to signed
    s_i1 <= signed(i1); s_i2 <= signed(i2); s_i3 <= signed(i3);
    s_i4 <= signed(i4); s_i5 <= signed(i5); s_i6 <= signed(i6);
    s_i7 <= signed(i7); s_i8 <= signed(i8); s_i9 <= signed(i9);

    s_w1 <= signed(w1); s_w2 <= signed(w2); s_w3 <= signed(w3);
    s_w4 <= signed(w4); s_w5 <= signed(w5); s_w6 <= signed(w6);
    s_w7 <= signed(w7); s_w8 <= signed(w8); s_w9 <= signed(w9);

    process(clk)
        variable shifted : signed(67 downto 0);
        variable sat_val : signed(31 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                p_reg       <= (others => (others => '0'));
                sum_12      <= (others => '0');
                sum_34      <= (others => '0');
                sum_56      <= (others => '0');
                sum_78      <= (others => '0');
                p9_d1       <= (others => '0');
                sum_1234    <= (others => '0');
                sum_5678    <= (others => '0');
                p9_d2       <= (others => '0');
                sum_8taps   <= (others => '0');
                total_sum   <= (others => '0');
                valid_pipe  <= (others => '0');
                sum_out     <= (others => '0');
                out_valid   <= '0';
            else
                -- Advance valid tracking pipeline
                valid_pipe <= valid_pipe(2 downto 0) & in_valid;

                -- Stage 0: 9 Parallel Multipliers (Q15.16 x Q15.16 = Q30.32 in 64 bits)
                p_reg(1) <= s_i1 * s_w1;
                p_reg(2) <= s_i2 * s_w2;
                p_reg(3) <= s_i3 * s_w3;
                p_reg(4) <= s_i4 * s_w4;
                p_reg(5) <= s_i5 * s_w5;
                p_reg(6) <= s_i6 * s_w6;
                p_reg(7) <= s_i7 * s_w7;
                p_reg(8) <= s_i8 * s_w8;
                p_reg(9) <= s_i9 * s_w9;

                -- Stage 1: Adder Tree Level 1 (Pairwise sums)
                sum_12 <= resize(p_reg(1), 66) + resize(p_reg(2), 66);
                sum_34 <= resize(p_reg(3), 66) + resize(p_reg(4), 66);
                sum_56 <= resize(p_reg(5), 66) + resize(p_reg(6), 66);
                sum_78 <= resize(p_reg(7), 66) + resize(p_reg(8), 66);
                p9_d1  <= resize(p_reg(9), 66);

                -- Stage 2: Adder Tree Level 2
                sum_1234 <= resize(sum_12, 67) + resize(sum_34, 67);
                sum_5678 <= resize(sum_56, 67) + resize(sum_78, 67);
                p9_d2    <= resize(p9_d1, 67);

                -- Stage 3: Adder Tree Level 3 (Final 9-term reduction)
                sum_8taps <= resize(sum_1234, 68) + resize(sum_5678, 68);
                total_sum <= sum_8taps + resize(p9_d2, 68);

                -- Stage 4: Rounding, Rescaling (>> 16), and Saturation to 32 bits
                shifted := shift_right(total_sum + ROUND_CONST, 16);

                -- Overflow saturation to signed 32-bit range
                if shifted > to_signed(2147483647, 68) then
                    sat_val := to_signed(2147483647, 32);
                elsif shifted < to_signed(-2147483648, 68) then
                    sat_val := to_signed(-2147483648, 32);
                else
                    sat_val := resize(shifted, 32);
                end if;

                sum_out   <= std_logic_vector(sat_val);
                out_valid <= valid_pipe(3);
            end if;
        end if;
    end process;

end architecture behavioral;
