----------------------------------------------------------------------------------
-- Module: accumulator.vhd
-- Description: Multi-Channel Accumulator and Bias Addition Stage with
--              On-Chip BRAM Partial-Sum Buffering.
--
-- Reproduces Equation (1) and Section 4.2 of:
-- "FPGA-Based CNN Acceleration on Zynq-7020 for Embedded Ship Recognition"
-- (Sensors 2026, 26, 1626)
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity accumulator is
    generic (
        DATA_WIDTH      : natural := 32;       -- 32-bit Q15.16 fixed-point
        MAX_SPATIAL_DIM : natural := 50176     -- Max spatial pixels: 224 x 224 = 50,176
    );
    port (
        clk             : in  std_logic;
        rst             : in  std_logic;

        -- Convolution partial sum input from mac_tree_9x
        conv_sum_in     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        conv_valid_in   : in  std_logic;

        -- Channel and spatial indexing
        c_in_idx        : in  std_logic_vector(11 downto 0); -- Current channel c (0 to Cin-1)
        cin_total       : in  std_logic_vector(11 downto 0); -- Total input channels Cin
        bias_in         : in  std_logic_vector(DATA_WIDTH-1 downto 0); -- Bias bo for current Cout
        pixel_addr      : in  std_logic_vector(15 downto 0); -- Spatial address 0 to HxW-1

        -- Final accumulated multi-channel output
        accum_out       : out std_logic_vector(DATA_WIDTH-1 downto 0);
        accum_valid     : out std_logic
    );
end entity accumulator;

architecture behavioral of accumulator is

    -- BRAM memory array to hold running partial sums across Cin channels
    -- (Consumes BRAM36 blocks matching Table 4's 58 BRAM count)
    type psum_ram_t is array (0 to MAX_SPATIAL_DIM-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal psum_ram : psum_ram_t := (others => (others => '0'));

    signal s_conv_in   : signed(DATA_WIDTH-1 downto 0);
    signal s_bias_in   : signed(DATA_WIDTH-1 downto 0);
    signal s_prev_psum : signed(DATA_WIDTH-1 downto 0);
    signal s_new_accum : signed(DATA_WIDTH downto 0); -- 33 bits for addition headroom

    signal int_addr    : integer range 0 to MAX_SPATIAL_DIM-1 := 0;
    signal is_first_c  : boolean := true;
    signal is_last_c   : boolean := false;

    -- Pipeline delay registers
    signal conv_valid_d: std_logic := '0';
    signal is_last_c_d : boolean := false;
    signal int_addr_d  : integer range 0 to MAX_SPATIAL_DIM-1 := 0;

begin

    s_conv_in <= signed(conv_sum_in);
    s_bias_in <= signed(bias_in);
    int_addr  <= to_integer(unsigned(pixel_addr));

    is_first_c <= (unsigned(c_in_idx) = 0);
    is_last_c  <= (unsigned(c_in_idx) = unsigned(cin_total) - 1);

    process(clk)
        variable psum_val : signed(DATA_WIDTH-1 downto 0);
        variable sat_out  : signed(DATA_WIDTH-1 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                conv_valid_d <= '0';
                is_last_c_d  <= false;
                accum_valid  <= '0';
                accum_out    <= (others => '0');
            else
                -- Stage 1: Read previous partial sum from BRAM
                conv_valid_d <= conv_valid_in;
                is_last_c_d  <= is_last_c;
                int_addr_d   <= int_addr;

                if conv_valid_in = '1' then
                    if is_first_c then
                        -- For c = 0: Initialize with bias bo
                        s_prev_psum <= s_bias_in;
                    else
                        -- For c > 0: Fetch accumulated sum from previous channels
                        s_prev_psum <= signed(psum_ram(int_addr));
                    end if;
                end if;

                -- Stage 2: Accumulate running sum
                if conv_valid_d = '1' then
                    s_new_accum <= resize(s_prev_psum, 33) + resize(s_conv_in, 33);

                    -- Saturation check
                    if s_new_accum > to_signed(2147483647, 33) then
                        sat_out := to_signed(2147483647, 32);
                    elsif s_new_accum < to_signed(-2147483648, 33) then
                        sat_out := to_signed(-2147483648, 32);
                    else
                        sat_out := resize(s_new_accum, 32);
                    end if;

                    -- Write updated partial sum back to BRAM for intermediate channels
                    psum_ram(int_addr_d) <= std_logic_vector(sat_out);

                    -- Output valid only on the final channel completion
                    if is_last_c_d then
                        accum_out   <= std_logic_vector(sat_out);
                        accum_valid <= '1';
                    else
                        accum_valid <= '0';
                    end if;
                else
                    accum_valid <= '0';
                end if;

            end if;
        end if;
    end process;

end architecture behavioral;
