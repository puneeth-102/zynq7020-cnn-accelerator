----------------------------------------------------------------------------------
-- Module: axi_lite_regs.vhd
-- Description: Standard AXI4-Lite Slave Register Bank for Accelerator Control
--              and Hyperparameter Configuration.
--
-- Exposes:
--   • Reg 0 (0x00): Control/Status (bit 0: start, bit 1: done, bit 2: reset)
--   • Reg 1 (0x04): Image Dimensions (W: [15:0], H: [31:16])
--   • Reg 2 (0x08): Channel Counts (Cin: [15:0], Cout: [31:16])
--   • Reg 3 (0x0C): Layer Config (bit 0: pad_en, bit 1: pool_en, bit 2: relu_en, [4:3]: mode)
--   • Reg 4 (0x10): Base Addresses / Status
--
-- Reproduces Section 4.1 & Figure 5 of:
-- "FPGA-Based CNN Acceleration on Zynq-7020 for Embedded Ship Recognition"
-- (Sensors 2026, 26, 1626)
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi_lite_regs is
    generic (
        C_S_AXI_DATA_WIDTH : integer := 32;
        C_S_AXI_ADDR_WIDTH : integer := 6
    );
    port (
        S_AXI_ACLK    : in  std_logic;
        S_AXI_ARESETN : in  std_logic;

        -- Write Address Channel
        S_AXI_AWADDR  : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
        S_AXI_AWVALID : in  std_logic;
        S_AXI_AWREADY : out std_logic;

        -- Write Data Channel
        S_AXI_WDATA   : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        S_AXI_WSTRB   : in  std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
        S_AXI_WVALID  : in  std_logic;
        S_AXI_WREADY  : out std_logic;

        -- Write Response Channel
        S_AXI_BRESP   : out std_logic_vector(1 downto 0);
        S_AXI_BVALID  : out std_logic;
        S_AXI_BREADY  : in  std_logic;

        -- Read Address Channel
        S_AXI_ARADDR  : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
        S_AXI_ARVALID : in  std_logic;
        S_AXI_ARREADY : out std_logic;

        -- Read Data Channel
        S_AXI_RDATA   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        S_AXI_RRESP   : out std_logic_vector(1 downto 0);
        S_AXI_RVALID  : out std_logic;
        S_AXI_RREADY  : in  std_logic;

        -- Decoded Control Signals to Accelerator Core
        reg_start     : out std_logic;
        reg_reset     : out std_logic;
        reg_img_w     : out std_logic_vector(10 downto 0);
        reg_img_h     : out std_logic_vector(10 downto 0);
        reg_cin       : out std_logic_vector(11 downto 0);
        reg_cout      : out std_logic_vector(11 downto 0);
        reg_pad_en    : out std_logic;
        reg_pool_en   : out std_logic;
        reg_relu_en   : out std_logic;
        reg_mode      : out std_logic_vector(1 downto 0); -- "00": Conv, "01": Pool, "10": FC

        -- Status input from Core
        core_done     : in  std_logic
    );
end entity axi_lite_regs;

architecture behavioral of axi_lite_regs is

    signal axi_awready : std_logic := '0';
    signal axi_wready  : std_logic := '0';
    signal axi_bvalid  : std_logic := '0';
    signal axi_arready : std_logic := '0';
    signal axi_rvalid  : std_logic := '0';
    signal axi_rdata   : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0) := (others => '0');

    -- Internal Registers
    signal slv_reg0 : std_logic_vector(31 downto 0) := (others => '0'); -- Control: [0]=start, [1]=done, [2]=reset
    signal slv_reg1 : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(224, 16)) & std_logic_vector(to_unsigned(224, 16)); -- H & W
    signal slv_reg2 : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(3, 16)) & std_logic_vector(to_unsigned(3, 16));     -- Cout & Cin
    signal slv_reg3 : std_logic_vector(31 downto 0) := x"00000007"; -- [0]=pad, [1]=pool, [2]=relu, [4:3]=mode
    signal slv_reg4 : std_logic_vector(31 downto 0) := (others => '0');

    signal aw_en : std_logic := '1';

begin

    S_AXI_AWREADY <= axi_awready;
    S_AXI_WREADY  <= axi_wready;
    S_AXI_BRESP   <= "00"; -- OKAY
    S_AXI_BVALID  <= axi_bvalid;
    S_AXI_ARREADY <= axi_arready;
    S_AXI_RDATA   <= axi_rdata;
    S_AXI_RRESP   <= "00"; -- OKAY
    S_AXI_RVALID  <= axi_rvalid;

    -- Port Mappings to Core
    reg_start   <= slv_reg0(0);
    reg_reset   <= slv_reg0(2);
    reg_img_w   <= slv_reg1(10 downto 0);
    reg_img_h   <= slv_reg1(26 downto 16);
    reg_cin     <= slv_reg2(11 downto 0);
    reg_cout    <= slv_reg2(27 downto 16);
    reg_pad_en  <= slv_reg3(0);
    reg_pool_en <= slv_reg3(1);
    reg_relu_en <= slv_reg3(2);
    reg_mode    <= slv_reg3(4 downto 3);

    -- AXI Write Channel Logic
    process(S_AXI_ACLK)
        variable loc_addr : std_logic_vector(3 downto 0);
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                axi_awready <= '0';
                axi_wready  <= '0';
                axi_bvalid  <= '0';
                aw_en       <= '1';
                slv_reg0    <= (others => '0');
            else
                if (axi_awready = '0' and S_AXI_AWVALID = '1' and S_AXI_WVALID = '1' and aw_en = '1') then
                    axi_awready <= '1';
                    axi_wready  <= '1';
                    aw_en       <= '0';
                else
                    axi_awready <= '0';
                    axi_wready  <= '0';
                    if S_AXI_BREADY = '1' and axi_bvalid = '1' then
                        aw_en <= '1';
                    end if;
                end if;

                if (S_AXI_WVALID = '1' and S_AXI_AWVALID = '1' and axi_awready = '1' and axi_wready = '1') then
                    loc_addr := S_AXI_AWADDR(5 downto 2);
                    case loc_addr is
                        when "0000" => slv_reg0 <= S_AXI_WDATA;
                        when "0001" => slv_reg1 <= S_AXI_WDATA;
                        when "0010" => slv_reg2 <= S_AXI_WDATA;
                        when "0011" => slv_reg3 <= S_AXI_WDATA;
                        when "0100" => slv_reg4 <= S_AXI_WDATA;
                        when others => null;
                    end case;
                elsif core_done = '1' then
                    slv_reg0(1) <= '1'; -- Set done flag
                    slv_reg0(0) <= '0'; -- Clear start flag
                end if;

                if (axi_awready = '1' and S_AXI_AWVALID = '1' and axi_wready = '1' and S_AXI_WVALID = '1' and axi_bvalid = '0') then
                    axi_bvalid <= '1';
                elsif S_AXI_BREADY = '1' and axi_bvalid = '1' then
                    axi_bvalid <= '0';
                end if;

            end if;
        end if;
    end process;

    -- AXI Read Channel Logic
    process(S_AXI_ACLK)
        variable loc_addr : std_logic_vector(3 downto 0);
    begin
        if rising_edge(S_AXI_ACLK) then
            if S_AXI_ARESETN = '0' then
                axi_arready <= '0';
                axi_rvalid  <= '0';
                axi_rdata   <= (others => '0');
            else
                if (axi_arready = '0' and S_AXI_ARVALID = '1') then
                    axi_arready <= '1';
                else
                    axi_arready <= '0';
                end if;

                if (axi_arready = '1' and S_AXI_ARVALID = '1' and axi_rvalid = '0') then
                    axi_rvalid <= '1';
                    loc_addr := S_AXI_ARADDR(5 downto 2);
                    case loc_addr is
                        when "0000" => axi_rdata <= slv_reg0;
                        when "0001" => axi_rdata <= slv_reg1;
                        when "0010" => axi_rdata <= slv_reg2;
                        when "0011" => axi_rdata <= slv_reg3;
                        when "0100" => axi_rdata <= slv_reg4;
                        when others => axi_rdata <= (others => '0');
                    end case;
                elsif axi_rvalid = '1' and S_AXI_RREADY = '1' then
                    axi_rvalid <= '0';
                end if;
            end if;
        end if;
    end process;

end architecture behavioral;
