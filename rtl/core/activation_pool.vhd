----------------------------------------------------------------------------------
-- Module: activation_pool.vhd
-- Description: Integrated ReLU Activation and 2x2 Max-Pooling Engine
--              with Stride 2 Support.
--
-- Reproduces Section 4.2 & Section 5.1 of:
-- "FPGA-Based CNN Acceleration on Zynq-7020 for Embedded Ship Recognition"
-- (Sensors 2026, 26, 1626)
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity activation_pool is
    generic (
        DATA_WIDTH      : natural := 32;     -- 32-bit Q15.16 format
        MAX_LINE_WIDTH  : natural := 224     -- Maximum feature map width
    );
    port (
        clk             : in  std_logic;
        rst             : in  std_logic;

        -- Control flags
        pool_en         : in  std_logic;     -- '1' to enable 2x2 Max-Pooling, '0' for Conv+ReLU only
        line_width      : in  std_logic_vector(10 downto 0); -- Feature map width W

        -- Input from Accumulator Stage
        in_data         : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        in_valid        : in  std_logic;

        -- Final Activated (and Pooled) Output Stream
        out_data        : out std_logic_vector(DATA_WIDTH-1 downto 0);
        out_valid       : out std_logic
    );
end entity activation_pool;

architecture behavioral of activation_pool is

    -- ReLU output signal
    signal relu_data    : std_logic_vector(DATA_WIDTH-1 downto 0);

    -- Internal Line Buffer for Max-Pooling (stores 1 row of pixels)
    type pool_line_t is array (0 to MAX_LINE_WIDTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal pool_line_mem: pool_line_t := (others => (others => '0'));

    -- Tracking indices
    signal col_cnt      : integer range 0 to MAX_LINE_WIDTH-1 := 0;
    signal row_even     : std_logic := '1'; -- '1' for row 0, 2, 4... '0' for row 1, 3, 5...
    signal current_w    : integer range 0 to MAX_LINE_WIDTH-1 := 224;

    -- Horizontal comparison registers
    signal prev_col_val : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal top_prev_val : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');

    -- Signed comparator function
    function max_signed(a, b : std_logic_vector(DATA_WIDTH-1 downto 0)) return std_logic_vector is
    begin
        if signed(a) >= signed(b) then
            return a;
        else
            return b;
        end if;
    end function;

begin

    current_w <= to_integer(unsigned(line_width));

    -- Combinational ReLU: Clip negative values to zero
    relu_data <= (others => '0') when in_data(DATA_WIDTH-1) = '1' else in_data;

    process(clk)
        variable top_left, top_right, bot_left, bot_right : std_logic_vector(DATA_WIDTH-1 downto 0);
        variable max_top, max_bot, max_2x2                : std_logic_vector(DATA_WIDTH-1 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                col_cnt      <= 0;
                row_even     <= '1';
                out_valid    <= '0';
                out_data     <= (others => '0');
                prev_col_val <= (others => '0');
                top_prev_val <= (others => '0');
            else
                if in_valid = '1' then
                    if pool_en = '0' then
                        -- Bypass pooling: pass ReLU output directly
                        out_data  <= relu_data;
                        out_valid <= '1';
                    else
                        -- 2x2 Max-Pooling with Stride 2
                        if row_even = '1' then
                            -- Even row: Save into pool line buffer
                            pool_line_mem(col_cnt) <= relu_data;
                            out_valid <= '0';
                        else
                            -- Odd row: Compare with upper row and previous column
                            if (col_cnt mod 2) = 0 then
                                -- Left column of 2x2 window
                                prev_col_val <= relu_data;
                                top_prev_val <= pool_line_mem(col_cnt);
                                out_valid    <= '0';
                            else
                                -- Right column of 2x2 window: Compute Max of 4 pixels
                                top_left  := top_prev_val;
                                top_right := pool_line_mem(col_cnt);
                                bot_left  := prev_col_val;
                                bot_right := relu_data;

                                max_top := max_signed(top_left, top_right);
                                max_bot := max_signed(bot_left, bot_right);
                                max_2x2 := max_signed(max_top, max_bot);

                                out_data  <= max_2x2;
                                out_valid <= '1';
                            end if;
                        end if;

                        -- Column and row counter management
                        if col_cnt = current_w - 1 then
                            col_cnt  <= 0;
                            row_even <= not row_even;
                        else
                            col_cnt  <= col_cnt + 1;
                        end if;

                    end if;
                else
                    out_valid <= '0';
                end if;
            end if;
        end if;
    end process;

end architecture behavioral;
