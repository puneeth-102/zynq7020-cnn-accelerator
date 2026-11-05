----------------------------------------------------------------------------------
-- Module: fc_engine.vhd
-- Description: Fully Connected (FC) Matrix-Vector MAC Acceleration Engine
--              with On-Chip Activation Vector Buffering and Q15.16 Arithmetic.
--
-- Reproduces Section 4.1 & Table 6 of:
-- "FPGA-Based CNN Acceleration on Zynq-7020 for Embedded Ship Recognition"
-- (Sensors 2026, 26, 1626)
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fc_engine is
    generic (
        DATA_WIDTH      : natural := 32;     -- 32-bit Q15.16
        MAX_INPUT_NODES : natural := 4096    -- Maximum activation vector length
    );
    port (
        clk             : in  std_logic;
        rst             : in  std_logic;

        -- Control signals
        start           : in  std_logic;
        vec_len         : in  std_logic_vector(12 downto 0); -- Total input activations Nin
        bias_in         : in  std_logic_vector(DATA_WIDTH-1 downto 0); -- Neuron bias bj
        relu_en         : in  std_logic;

        -- Input activation loading (from previous Conv/Pool or DDR)
        act_in          : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        act_valid       : in  std_logic;

        -- Streaming weights from DMA (streamed contiguously per neuron)
        w_in            : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        w_valid         : in  std_logic;

        -- Output neuron score
        fc_out          : out std_logic_vector(DATA_WIDTH-1 downto 0);
        fc_out_valid    : out std_logic
    );
end entity fc_engine;

architecture behavioral of fc_engine is

    -- On-chip BRAM to store the activation vector x
    type act_mem_t is array (0 to MAX_INPUT_NODES-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
    signal act_ram      : act_mem_t := (others => (others => '0'));

    signal act_wr_ptr   : integer range 0 to MAX_INPUT_NODES-1 := 0;
    signal act_rd_ptr   : integer range 0 to MAX_INPUT_NODES-1 := 0;
    signal target_len   : integer range 0 to MAX_INPUT_NODES-1 := 4096;

    -- Dot product computation signals
    signal s_act        : signed(DATA_WIDTH-1 downto 0) := (others => '0');
    signal s_wt         : signed(DATA_WIDTH-1 downto 0) := (others => '0');
    signal prod_64      : signed(63 downto 0) := (others => '0');
    signal accum_64     : signed(63 downto 0) := (others => '0');

    signal is_accumulating : boolean := false;
    signal w_valid_d    : std_logic := '0';
    signal is_last_node : boolean := false;
    signal is_last_node_d: boolean := false;

    constant ROUND_HALF : signed(63 downto 0) := to_signed(32768, 64);

begin

    target_len <= to_integer(unsigned(vec_len));

    -- Activation loading process
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                act_wr_ptr <= 0;
            elsif act_valid = '1' then
                act_ram(act_wr_ptr) <= act_in;
                if act_wr_ptr = target_len - 1 then
                    act_wr_ptr <= 0;
                else
                    act_wr_ptr <= act_wr_ptr + 1;
                end if;
            end if;
        end if;
    end process;

    -- MAC Execution process
    process(clk)
        variable shifted_val : signed(63 downto 0);
        variable sat_val     : signed(31 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' then
                act_rd_ptr      <= 0;
                accum_64        <= (others => '0');
                is_accumulating <= false;
                w_valid_d       <= '0';
                is_last_node_d  <= false;
                fc_out_valid    <= '0';
                fc_out          <= (others => '0');
            else
                w_valid_d      <= w_valid;
                is_last_node_d <= is_last_node;

                if start = '1' then
                    act_rd_ptr      <= 0;
                    -- Initialize accumulator with bias in 64-bit Q30.32 format (shifted left 16)
                    accum_64        <= shift_left(resize(signed(bias_in), 64), 16);
                    is_accumulating <= true;
                end if;

                if w_valid = '1' and is_accumulating then
                    -- Read activation and incoming weight
                    s_act   <= signed(act_ram(act_rd_ptr));
                    s_wt    <= signed(w_in);
                    prod_64 <= signed(act_ram(act_rd_ptr)) * signed(w_in);

                    if act_rd_ptr = target_len - 1 then
                        is_last_node <= true;
                        act_rd_ptr   <= 0;
                    else
                        is_last_node <= false;
                        act_rd_ptr   <= act_rd_ptr + 1;
                    end if;
                end if;

                -- Pipelined accumulation
                if w_valid_d = '1' then
                    accum_64 <= accum_64 + prod_64;

                    if is_last_node_d then
                        -- Finished dot product for this neuron: Rescale back to Q15.16
                        shifted_val := shift_right(accum_64 + prod_64 + ROUND_HALF, 16);

                        -- Saturation to 32 bits
                        if shifted_val > to_signed(2147483647, 64) then
                            sat_val := to_signed(2147483647, 32);
                        elsif shifted_val < to_signed(-2147483648, 64) then
                            sat_val := to_signed(-2147483648, 32);
                        else
                            sat_val := resize(shifted_val, 32);
                        end if;

                        -- Apply ReLU if enabled
                        if relu_en = '1' and sat_val < 0 then
                            fc_out <= (others => '0');
                        else
                            fc_out <= std_logic_vector(sat_val);
                        end if;

                        fc_out_valid    <= '1';
                        is_accumulating <= false;
                    else
                        fc_out_valid <= '0';
                    end if;
                else
                    fc_out_valid <= '0';
                end if;

            end if;
        end if;
    end process;

end architecture behavioral;
