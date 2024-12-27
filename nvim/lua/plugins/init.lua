return {
    -- Look and feel
    {
        "ellisonleao/gruvbox.nvim",
        priority = 1000,
        config = true,
    },
    {
        "akinsho/bufferline.nvim",
        version = "*",
        dependencies = "nvim-tree/nvim-web-devicons",
    },
    "nvim-lualine/lualine.nvim",

    -- keymaps
    {
        "windwp/nvim-autopairs",
        event = "InsertEnter",
        opts = {},
    },
    {
        "kylechui/nvim-surround",
        version = "*",
        event = "VeryLazy",
        config = function()
            require("nvim-surround").setup({
                -- Configuration here, or leave empty to use defaults
            })
        end,
    },
    "folke/which-key.nvim",

    -- functionality
    "andymass/vim-matchup",
    "tpope/vim-repeat",
    "mbbill/undotree",
    "jdhao/whitespace.nvim",
    "lambdalisue/suda.vim",
    "xiyaowong/nvim-cursorword",
    "ahmedkhalf/project.nvim",
    "mfussenegger/nvim-dap",
    "rcarriga/nvim-dap-ui",
    "preservim/nerdtree",
    {
        "norcalli/nvim-colorizer.lua",
        config = function()
            require("colorizer").setup()
        end,
    },
    {
        "folke/neodev.nvim",
        dependencies = {
            "rcarriga/nvim-dap-ui",
        },
        opts = {
            library = {
                plugins = {
                    "nvim-dap-ui",
                },
                types = true,
            },
        },
    },
}
