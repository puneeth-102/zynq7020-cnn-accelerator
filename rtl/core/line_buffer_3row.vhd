----------------------------------------------------------------------------------
-- Module: line_buffer_3row.vhd
-- Description: Cascaded 3-row line buffer and 3x3 sliding window extractor
--              with integrated zero-padding support.
-- 
-- Reproduces Section 4.2 & 4.3 (Figure 4, Figure 6) of:
-- "FPGA-Based CNN Acceleration on Zynq-7020 for Embedded Ship Recognition"
-- (Sensors 2026, 26, 1626)
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity line_buffer_3row is
    generic (
        DATA_WIDTH      : natural := 32;     -- 32-bit Q15.16 fixed-point format
        MAX_LINE_WIDTH  : natural := 224     -- Maximum feature map width (224 for input)
    );
    port (
        clk             : in  std_logic;
        rst             : in  std_logic;
        
        -- Configuration parameters from AXI-Lite controller
        line_width      : in  std_logic_vector(10 downto 0); -- Dynamic width W (14 to 224)
        padding_en      : in  std_logic;                     -- '1' for zero-padding, '0' otherwise
        
        -- Input Streaming Interface
        in_data         : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        in_valid        : in  std_logic;
        in_ready        : out std_logic;
        
        -- 3x3 Sliding Window Output (i1 to i9 matching Figure 4 & Figure 6)
        -- Row 0: i1 (top-left),    i2 (top-mid),    i3 (top-right)
        -- Row 1: i4 (mid-left),    i5 (center),     i6 (mid-right)
        -- Row 2: i7 (bot-left),    i8 (bot-mid),    i9 (bot-right)
        win_i1          : out std_logic_vector(DATA_WIDTH-1 downto 0);
        win_i2          : out std_logic_vector(DATA_WIDTH-1 downto 0);
        win_i3          : out std_logic_vector(DATA_WIDTH-1 downto 0);
        win_i4          : out std_logic_vector(DATA_WIDTH-1 downto 0);
        win_i5          : out std_logic_vector(DATA_WIDTH-1 downto 0);
        win_i6          : out std_logic_vector(DATA_WIDTH-1 downto 0);
        win_i7          : out std_logic_vector(DATA_WIDTH-1 downto 0);
        win_i8          : out std_logic_vector(DATA_WIDTH-1 downto 0);
        win_i9          : out std_logic_vector(DATA_WIDTH-1 downto 0);
        win_valid       : out std_logic
    );
end entity line_buffer_3row;

architecture behavioral of line_buffer_3row is

    -- Line buffer memory arrays inferred as Block RAMs (BRAM36)
    type ram_type is array (0 to MAX_LINE_WIDTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal ram_line0 : ram_type := (others => (others => '0'));
    signal ram_line1 : ram_type := (others => (others => '0'));

    -- Pointer registers
    signal wr_ptr       : integer range 0 to MAX_LINE_WIDTH-1 := 0;
    signal rd_ptr       : integer range 0 to MAX_LINE_WIDTH-1 := 0;

    -- Shift registers to extract 3 horizontal taps per row
    signal row0_tap0, row0_tap1, row0_tap2 : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal row1_tap0, row1_tap1, row1_tap2 : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal row2_tap0, row2_tap1, row2_tap2 : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');

    -- Line buffer data streams
    signal line0_out    : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal line1_out    : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');

    -- Priming counter (waits until 2 full lines + 3 taps are loaded)
    signal primed_pixels: natural := 0;
    signal is_primed    : std_logic := '0';

    -- Coordinate tracking for padding injection
    signal col_idx      : integer range 0 to MAX_LINE_WIDTH-1 := 0;
    signal row_idx      : natural := 0;
    signal current_w    : integer range 0 to MAX_LINE_WIDTH-1 := 224;

begin

    in_ready <= '1'; -- Streaming buffer accepts one pixel per clock cycle
    current_w <= to_integer(unsigned(line_width));

    -- Dual-port synchronous BRAM inference process
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                wr_ptr        <= 0;
                rd_ptr        <= 0;
                primed_pixels <= 0;
                is_primed     <= '0';
                col_idx       <= 0;
                row_idx       <= 0;
                win_valid     <= '0';
            elsif in_valid = '1' then
                -- 1. Read synchronous outputs from Line Buffers
                line1_out <= ram_line1(rd_ptr);
                line0_out <= ram_line0(rd_ptr);

                -- 2. Write new incoming pixel to Line 1; sample evicted from Line 1 writes to Line 0
                ram_line1(wr_ptr) <= in_data;
                ram_line0(wr_ptr) <= line1_out;

                -- 3. Shift registers: Advance 3x3 window registers horizontally
                row2_tap2 <= in_data;
                row2_tap1 <= row2_tap2;
                row2_tap0 <= row2_tap1;

                row1_tap2 <= line1_out;
                row1_tap1 <= row1_tap2;
                row1_tap0 <= row1_tap1;

                row0_tap2 <= line0_out;
                row0_tap1 <= row0_tap2;
                row0_tap0 <= row0_tap1;

                -- 4. Advance circular read/write pointers
                if wr_ptr = current_w - 1 then
                    wr_ptr <= 0;
                else
                    wr_ptr <= wr_ptr + 1;
                end if;

                if rd_ptr = current_w - 1 then
                    rd_ptr <= 0;
                else
                    rd_ptr <= rd_ptr + 1;
                end if;

                -- 5. Priming logic: 2 rows + 3 initial samples
                if is_primed = '0' then
                    if primed_pixels = (2 * current_w + 2) then
                        is_primed <= '1';
                        win_valid <= '1';
                    else
                        primed_pixels <= primed_pixels + 1;
                        win_valid <= '0';
                    end if;
                else
                    win_valid <= '1';
                end if;

                -- 6. Track 2D spatial coordinate (column, row)
                if col_idx = current_w - 1 then
                    col_idx <= 0;
                    row_idx <= row_idx + 1;
                else
                    col_idx <= col_idx + 1;
                end if;

            else
                win_valid <= '0';
            end if;
        end if;
    end process;

    -- Output multiplexing with zero-padding logic
    -- When padding_en is active, border pixels are zeroed on the fly
    win_i1 <= (others => '0') when (padding_en = '1' and (row_idx = 0 or col_idx = 0)) else row0_tap0;
    win_i2 <= (others => '0') when (padding_en = '1' and (row_idx = 0))                else row0_tap1;
    win_i3 <= (others => '0') when (padding_en = '1' and (row_idx = 0 or col_idx = current_w - 1)) else row0_tap2;

    win_i4 <= (others => '0') when (padding_en = '1' and (col_idx = 0))                else row1_tap0;
    win_i5 <= row1_tap1; -- Center pixel is always within bounds after priming
    win_i6 <= (others => '0') when (padding_en = '1' and (col_idx = current_w - 1))    else row1_tap2;

    win_i7 <= (others => '0') when (padding_en = '1' and (col_idx = 0))                else row2_tap0;
    win_i8 <= row2_tap1;
    win_i9 <= (others => '0') when (padding_en = '1' and (col_idx = current_w - 1))    else row2_tap2;

end architecture behavioral;
