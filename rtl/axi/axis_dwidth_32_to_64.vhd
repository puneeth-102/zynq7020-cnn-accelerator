----------------------------------------------------------------------------------
-- Module: axis_dwidth_32_to_64.vhd
-- Description: Packs two consecutive 32-bit Q15.16 output samples into one
--              64-bit beat for high-bandwidth AXI DMA S2MM write back to DDR.
--
-- Reproduces Section 4.5.2 of:
-- "FPGA-Based CNN Acceleration on Zynq-7020 for Embedded Ship Recognition"
-- (Sensors 2026, 26, 1626)
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_dwidth_32_to_64 is
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;

        -- 32-bit Slave Interface (from Accelerator Output)
        s_axis_tdata : in  std_logic_vector(31 downto 0);
        s_axis_tvalid: in  std_logic;
        s_axis_tready: out std_logic;
        s_axis_tlast : in  std_logic;

        -- 64-bit Master Interface (to AXI DMA S2MM via HP0)
        m_axis_tdata : out std_logic_vector(63 downto 0);
        m_axis_tvalid: out std_logic;
        m_axis_tready: in  std_logic;
        m_axis_tlast : out std_logic
    );
end entity axis_dwidth_32_to_64;

architecture behavioral of axis_dwidth_32_to_64 is

    type state_t is (WAIT_FIRST, WAIT_SECOND, TRANSMIT);
    signal state : state_t := WAIT_FIRST;

    signal word0 : std_logic_vector(31 downto 0) := (others => '0');

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state         <= WAIT_FIRST;
                s_axis_tready <= '1';
                m_axis_tvalid <= '0';
                m_axis_tdata  <= (others => '0');
                m_axis_tlast  <= '0';
                word0         <= (others => '0');
            else
                case state is
                    when WAIT_FIRST =>
                        m_axis_tvalid <= '0';
                        s_axis_tready <= '1';
                        if s_axis_tvalid = '1' then
                            word0 <= s_axis_tdata;
                            if s_axis_tlast = '1' then
                                -- Odd final sample: Pad high 32 bits with zeros and transmit
                                m_axis_tdata  <= (31 downto 0 => '0') & s_axis_tdata;
                                m_axis_tvalid <= '1';
                                m_axis_tlast  <= '1';
                                s_axis_tready <= '0';
                                state         <= TRANSMIT;
                            else
                                state <= WAIT_SECOND;
                            end if;
                        end if;

                    when WAIT_SECOND =>
                        if s_axis_tvalid = '1' then
                            -- Pack Word 0 (lower) and Word 1 (upper)
                            m_axis_tdata  <= s_axis_tdata & word0;
                            m_axis_tvalid <= '1';
                            m_axis_tlast  <= s_axis_tlast;
                            s_axis_tready <= '0';
                            state         <= TRANSMIT;
                        end if;

                    when TRANSMIT =>
                        if m_axis_tready = '1' then
                            m_axis_tvalid <= '0';
                            s_axis_tready <= '1';
                            state         <= WAIT_FIRST;
                        end if;

                    when others =>
                        state <= WAIT_FIRST;
                end case;
            end if;
        end if;
    end process;

end architecture behavioral;
