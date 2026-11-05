----------------------------------------------------------------------------------
-- Module: axis_dwidth_64_to_32.vhd
-- Description: Unpacks 64-bit HP0 AXI-Stream DMA beats into two consecutive
--              32-bit Q15.16 samples for the streaming compute pipeline.
--
-- Reproduces Section 4.5.2 of:
-- "FPGA-Based CNN Acceleration on Zynq-7020 for Embedded Ship Recognition"
-- (Sensors 2026, 26, 1626)
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_dwidth_64_to_32 is
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;

        -- 64-bit Slave Interface (from AXI DMA MM2S)
        s_axis_tdata : in  std_logic_vector(63 downto 0);
        s_axis_tvalid: in  std_logic;
        s_axis_tready: out std_logic;
        s_axis_tlast : in  std_logic;

        -- 32-bit Master Interface (to Accelerator Input Buffer)
        m_axis_tdata : out std_logic_vector(31 downto 0);
        m_axis_tvalid: out std_logic;
        m_axis_tready: in  std_logic;
        m_axis_tlast : out std_logic
    );
end entity axis_dwidth_64_to_32;

architecture behavioral of axis_dwidth_64_to_32 is

    type state_t is (IDLE, SEND_WORD0, SEND_WORD1);
    signal state : state_t := IDLE;

    signal latched_high : std_logic_vector(31 downto 0) := (others => '0');
    signal latched_last : std_logic := '0';

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state         <= IDLE;
                s_axis_tready <= '0';
                m_axis_tvalid <= '0';
                m_axis_tdata  <= (others => '0');
                m_axis_tlast  <= '0';
            else
                case state is
                    when IDLE =>
                        s_axis_tready <= '1';
                        if s_axis_tvalid = '1' then
                            -- Latch upper 32 bits and tlast
                            latched_high  <= s_axis_tdata(63 downto 32);
                            latched_last  <= s_axis_tlast;
                            -- Output lower 32 bits immediately
                            m_axis_tdata  <= s_axis_tdata(31 downto 0);
                            m_axis_tvalid <= '1';
                            m_axis_tlast  <= '0';
                            s_axis_tready <= '0';
                            state         <= SEND_WORD1;
                        else
                            m_axis_tvalid <= '0';
                        end if;

                    when SEND_WORD1 =>
                        if m_axis_tready = '1' then
                            -- Now output upper 32 bits
                            m_axis_tdata  <= latched_high;
                            m_axis_tvalid <= '1';
                            m_axis_tlast  <= latched_last;
                            state         <= IDLE;
                            s_axis_tready <= '1';
                        end if;

                    when others =>
                        state <= IDLE;
                end case;
            end if;
        end if;
    end process;

end architecture behavioral;
