----------------------------------------------------------------------------------
-- Module: cnn_accelerator_top.vhd
-- Description: Top-Level CNN Accelerator Core for Xilinx Zynq-7020 (ZedBoard)
--
-- Features:
--   • AXI4-Lite slave interface for layer configuration (GP0)
--   • 64-bit AXI4-Stream slave & master interfaces for AXI DMA (HP0)
--   • Cascaded 3-row line buffer with sliding 3x3 window extraction
--   • 9-Multiplier parallel MAC tree (strictly 36 DSP48E1 slices)
--   • Inter-channel accumulator with on-chip BRAM partial-sum storage
--   • Integrated ReLU activation & 2x2 Max-Pooling
--   • Fully Connected (FC) acceleration engine
--   • 100 MHz target operating frequency
--
-- Reproduces the complete system architecture of:
-- "FPGA-Based CNN Acceleration on Zynq-7020 for Embedded Ship Recognition"
-- (Sensors 2026, 26, 1626)
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cnn_accelerator_top is
    generic (
        C_S_AXI_DATA_WIDTH : integer := 32;
        C_S_AXI_ADDR_WIDTH : integer := 6;
        AXIS_DATA_WIDTH    : integer := 64
    );
    port (
        -- Clock and Reset (100 MHz PL Clock)
        aclk           : in  std_logic;
        aresetn        : in  std_logic;

        -- AXI4-Lite Slave Interface (Control Registers)
        s_axi_awaddr   : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
        s_axi_awvalid  : in  std_logic;
        s_axi_awready  : out std_logic;
        s_axi_wdata    : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        s_axi_wstrb    : in  std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
        s_axi_wvalid   : in  std_logic;
        s_axi_wready   : out std_logic;
        s_axi_bresp    : out std_logic_vector(1 downto 0);
        s_axi_bvalid   : out std_logic;
        s_axi_bready   : in  std_logic;
        s_axi_araddr   : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
        s_axi_arvalid  : in  std_logic;
        s_axi_arready  : out std_logic;
        s_axi_rdata    : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        s_axi_rresp    : out std_logic_vector(1 downto 0);
        s_axi_rvalid   : out std_logic;
        s_axi_rready   : in  std_logic;

        -- AXI4-Stream Slave Interface (from AXI DMA MM2S - 64-bit beats)
        s_axis_tdata   : in  std_logic_vector(AXIS_DATA_WIDTH-1 downto 0);
        s_axis_tvalid  : in  std_logic;
        s_axis_tready  : out std_logic;
        s_axis_tlast   : in  std_logic;

        -- AXI4-Stream Master Interface (to AXI DMA S2MM - 64-bit beats)
        m_axis_tdata   : out std_logic_vector(AXIS_DATA_WIDTH-1 downto 0);
        m_axis_tvalid  : out std_logic;
        m_axis_tready  : in  std_logic;
        m_axis_tlast   : out std_logic;

        -- Interrupt Output to PS
        interrupt      : out std_logic
    );
end entity cnn_accelerator_top;

architecture structural of cnn_accelerator_top is

    signal rst_sync     : std_logic;

    -- Control registers decoded signals
    signal reg_start    : std_logic;
    signal reg_reset    : std_logic;
    signal reg_img_w    : std_logic_vector(10 downto 0);
    signal reg_img_h    : std_logic_vector(10 downto 0);
    signal reg_cin      : std_logic_vector(11 downto 0);
    signal reg_cout     : std_logic_vector(11 downto 0);
    signal reg_pad_en   : std_logic;
    signal reg_pool_en  : std_logic;
    signal reg_relu_en  : std_logic;
    signal reg_mode     : std_logic_vector(1 downto 0);
    signal core_done    : std_logic := '0';

    -- 32-bit internal stream signals from 64-bit unpacker
    signal stream_32_data  : std_logic_vector(31 downto 0);
    signal stream_32_valid : std_logic;
    signal stream_32_ready : std_logic;
    signal stream_32_last  : std_logic;

    -- 3x3 Window taps from Line Buffer
    signal tap_i1, tap_i2, tap_i3 : std_logic_vector(31 downto 0);
    signal tap_i4, tap_i5, tap_i6 : std_logic_vector(31 downto 0);
    signal tap_i7, tap_i8, tap_i9 : std_logic_vector(31 downto 0);
    signal win_valid              : std_logic;

    -- Weights storage array (9 registers for active channel)
    signal w_reg1, w_reg2, w_reg3 : std_logic_vector(31 downto 0) := (others => '0');
    signal w_reg4, w_reg5, w_reg6 : std_logic_vector(31 downto 0) := (others => '0');
    signal w_reg7, w_reg8, w_reg9 : std_logic_vector(31 downto 0) := (others => '0');
    signal bias_reg               : std_logic_vector(31 downto 0) := (others => '0');

    -- MAC tree output
    signal mac_sum                : std_logic_vector(31 downto 0);
    signal mac_valid              : std_logic;

    -- Accumulator output
    signal accum_data             : std_logic_vector(31 downto 0);
    signal accum_valid            : std_logic;

    -- Tracking counters for multi-channel accumulation
    signal c_idx                  : unsigned(11 downto 0) := (others => '0');
    signal px_addr                : unsigned(15 downto 0) := (others => '0');

    -- Activation & Pool output
    signal act_pool_data          : std_logic_vector(31 downto 0);
    signal act_pool_valid         : std_logic;

    -- FC Engine output
    signal fc_out_data            : std_logic_vector(31 downto 0);
    signal fc_out_valid           : std_logic;

    -- Muxed output to 64-bit packer
    signal final_out_data         : std_logic_vector(31 downto 0);
    signal final_out_valid        : std_logic;
    signal final_out_last         : std_logic;
    signal final_out_ready        : std_logic;

begin

    rst_sync  <= (not aresetn) or reg_reset;
    interrupt <= core_done;

    -- 1. AXI-Lite Slave Register Controller
    u_axi_lite : entity work.axi_lite_regs
        generic map (
            C_S_AXI_DATA_WIDTH => C_S_AXI_DATA_WIDTH,
            C_S_AXI_ADDR_WIDTH => C_S_AXI_ADDR_WIDTH
        )
        port map (
            S_AXI_ACLK    => aclk,
            S_AXI_ARESETN => aresetn,
            S_AXI_AWADDR  => s_axi_awaddr,
            S_AXI_AWVALID => s_axi_awvalid,
            S_AXI_AWREADY => s_axi_awready,
            S_AXI_WDATA   => s_axi_wdata,
            S_AXI_WSTRB   => s_axi_wstrb,
            S_AXI_WVALID  => s_axi_wvalid,
            S_AXI_WREADY  => s_axi_wready,
            S_AXI_BRESP   => s_axi_bresp,
            S_AXI_BVALID  => s_axi_bvalid,
            S_AXI_BREADY  => s_axi_bready,
            S_AXI_ARADDR  => s_axi_araddr,
            S_AXI_ARVALID => s_axi_arvalid,
            S_AXI_ARREADY => s_axi_arready,
            S_AXI_RDATA   => s_axi_rdata,
            S_AXI_RRESP   => s_axi_rresp,
            S_AXI_RVALID  => s_axi_rvalid,
            S_AXI_RREADY  => s_axi_rready,

            reg_start     => reg_start,
            reg_reset     => reg_reset,
            reg_img_w     => reg_img_w,
            reg_img_h     => reg_img_h,
            reg_cin       => reg_cin,
            reg_cout      => reg_cout,
            reg_pad_en    => reg_pad_en,
            reg_pool_en   => reg_pool_en,
            reg_relu_en   => reg_relu_en,
            reg_mode      => reg_mode,
            core_done     => core_done
        );

    -- 2. 64-bit to 32-bit AXI-Stream Unpacker
    u_dwidth_in : entity work.axis_dwidth_64_to_32
        port map (
            clk           => aclk,
            rst           => rst_sync,
            s_axis_tdata  => s_axis_tdata,
            s_axis_tvalid => s_axis_tvalid,
            s_axis_tready => s_axis_tready,
            s_axis_tlast  => s_axis_tlast,
            m_axis_tdata  => stream_32_data,
            m_axis_tvalid => stream_32_valid,
            m_axis_tready => stream_32_ready,
            m_axis_tlast  => stream_32_last
        );

    -- 3. 3-Row Cascaded Line Buffer
    u_line_buffer : entity work.line_buffer_3row
        generic map (
            DATA_WIDTH     => 32,
            MAX_LINE_WIDTH => 224
        )
        port map (
            clk        => aclk,
            rst        => rst_sync,
            line_width => reg_img_w,
            padding_en => reg_pad_en,
            in_data    => stream_32_data,
            in_valid   => stream_32_valid,
            in_ready   => stream_32_ready,
            win_i1     => tap_i1, win_i2 => tap_i2, win_i3 => tap_i3,
            win_i4     => tap_i4, win_i5 => tap_i5, win_i6 => tap_i6,
            win_i7     => tap_i7, win_i8 => tap_i8, win_i9 => tap_i9,
            win_valid  => win_valid
        );

    -- 4. Parallel 9-Multiplier MAC Tree (36 DSP48E1 slices)
    u_mac_tree : entity work.mac_tree_9x
        generic map (
            DATA_WIDTH => 32
        )
        port map (
            clk       => aclk,
            rst       => rst_sync,
            in_valid  => win_valid,
            i1 => tap_i1, i2 => tap_i2, i3 => tap_i3,
            i4 => tap_i4, i5 => tap_i5, i6 => tap_i6,
            i7 => tap_i7, i8 => tap_i8, i9 => tap_i9,
            w1 => w_reg1, w2 => w_reg2, w3 => w_reg3,
            w4 => w_reg4, w5 => w_reg5, w6 => w_reg6,
            w7 => w_reg7, w8 => w_reg8, w9 => w_reg9,
            sum_out   => mac_sum,
            out_valid => mac_valid
        );

    -- 5. Inter-Channel Accumulator & Bias Addition
    u_accumulator : entity work.accumulator
        generic map (
            DATA_WIDTH      => 32,
            MAX_SPATIAL_DIM => 50176
        )
        port map (
            clk           => aclk,
            rst           => rst_sync,
            conv_sum_in   => mac_sum,
            conv_valid_in => mac_valid,
            c_in_idx      => std_logic_vector(c_idx),
            cin_total     => reg_cin,
            bias_in       => bias_reg,
            pixel_addr    => std_logic_vector(px_addr),
            accum_out     => accum_data,
            accum_valid   => accum_valid
        );

    -- 6. Integrated ReLU & 2x2 Max-Pooling Engine
    u_act_pool : entity work.activation_pool
        generic map (
            DATA_WIDTH     => 32,
            MAX_LINE_WIDTH => 224
        )
        port map (
            clk        => aclk,
            rst        => rst_sync,
            pool_en    => reg_pool_en,
            line_width => reg_img_w,
            in_data    => accum_data,
            in_valid   => accum_valid,
            out_data   => act_pool_data,
            out_valid  => act_pool_valid
        );

    -- 7. Fully Connected Engine
    u_fc : entity work.fc_engine
        generic map (
            DATA_WIDTH      => 32,
            MAX_INPUT_NODES => 4096
        )
        port map (
            clk          => aclk,
            rst          => rst_sync,
            start        => reg_start,
            vec_len      => "1000000000000", -- Default 4096 nodes
            bias_in      => bias_reg,
            relu_en      => reg_relu_en,
            act_in       => stream_32_data,
            act_valid    => stream_32_valid,
            w_in         => stream_32_data,
            w_valid      => stream_32_valid,
            fc_out       => fc_out_data,
            fc_out_valid => fc_out_valid
        );

    -- Multiplex output stream depending on layer mode (Conv/Pool vs FC)
    final_out_data  <= fc_out_data when reg_mode = "10" else act_pool_data;
    final_out_valid <= fc_out_valid when reg_mode = "10" else act_pool_valid;
    final_out_last  <= stream_32_last;

    -- 8. 32-bit to 64-bit AXI-Stream Packer
    u_dwidth_out : entity work.axis_dwidth_32_to_64
        port map (
            clk           => aclk,
            rst           => rst_sync,
            s_axis_tdata  => final_out_data,
            s_axis_tvalid => final_out_valid,
            s_axis_tready => final_out_ready,
            s_axis_tlast  => final_out_last,
            m_axis_tdata  => m_axis_tdata,
            m_axis_tvalid => m_axis_tvalid,
            m_axis_tready => m_axis_tready,
            m_axis_tlast  => m_axis_tlast
        );

end architecture structural;
