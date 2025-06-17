-- Load default lsp-zero keymaps
local lsp_zero = require("lsp-zero")
local telescope = require("telescope.builtin")

-- Install LSP servers automatically through Mason
require("mason").setup()
require("mason-lspconfig").setup({ automatic_installation = true })


lsp_zero.on_attach(function(_, bufnr)
    -- see :help lsp-zero-keybindings to learn the available actions
    lsp_zero.default_keymaps({ buffer = bufnr })

    local opts = { buffer = bufnr, remap = false }
    vim.keymap.set("n", "<leader>vc", vim.lsp.buf.code_action, opts)
    vim.keymap.set("n", "<leader>vr", vim.lsp.buf.rename, opts)

    vim.keymap.set("n", "<leader>en", vim.diagnostic.goto_next, opts)
    vim.keymap.set("n", "<leader>ep", vim.diagnostic.goto_prev, opts)
    vim.keymap.set("n", "<leader>ei", vim.diagnostic.open_float, opts)
    vim.keymap.set("i", "<C-h>", vim.lsp.buf.signature_help, opts)

    vim.keymap.set("n", "gr", function()
        telescope.lsp_references({
            include_declaration = false,
            show_line = false,
            fname_width = 64,
        })
    end, opts)
    vim.keymap.set("n", "gd", function()
        telescope.lsp_definitions({
            show_line = false,
            fname_width = 64,
        })
    end, opts)
    vim.keymap.set("n", "gi", function()
        telescope.lsp_implementations({
            show_line = false,
            fname_width = 64,
        })
    end, opts)
end)

lsp_zero.format_on_save({
    format_opts = {
        async = true,
        timeout_ms = 10000,
    },
    servers = {
        ["efm"] = { "lua" },
        ["gopls"] = { "go" },
        ["rust_analyzer"] = { "rust" },
        ["pylsp"] = { "python" },
        -- C/C++ will use clangd's formatter automatically
    },
})

-- Setup LSP servers with error handling to make config portable
local lspconfig = require("lspconfig")

-- Helper function to safely setup LSP servers
local function safe_setup(server, config)
    config = config or {}
    pcall(function()
        lspconfig[server].setup(config)
    end)
end

-- go
safe_setup("golangci_lint_ls", {
    root_dir = require("lspconfig.util").root_pattern(
        "go.mod",
        "go.work",
        ".golangci.yml",
        ".golangci.yaml",
        ".golangci.toml",
        ".golangci.json",
        ".git"
    ),
})
safe_setup("gopls", {
    settings = {
        gopls = {
            gofumpt = true,
            staticcheck = true,
        },
    },
})
-- rust
safe_setup("rust_analyzer", {
    settings = {
        ["rust-analyzer"] = {
            diagnostics = {
                enable = false,
            },
            cargo = {
                allFeatures = true,
            },
        },
    },
})
-- lua
pcall(function()
    lspconfig.lua_ls.setup(lsp_zero.nvim_lua_ls())
end)
-- C/C++
safe_setup("clangd", {
    cmd = {
        "clangd",
        "--background-index",
        "--clang-tidy",
        "--header-insertion=never", -- avoid automatic imports
    },
})

-- Python
safe_setup("pylsp", {
    settings = {
        pylsp = {
            plugins = {
                pycodestyle = {
                    maxLineLength = 120
                }
            }
        }
    }
})

-- Protobuf (buf LSP)
safe_setup("buf_ls", {
    filetypes = { "proto" },
})

-- efm
local stylua = {
    formatCommand = "stylua -",
    formatStdin = true,
}
local prettier = {
    formatCommand = 'prettierd "${INPUT}"',
    formatStdin = true,
    env = {
        string.format(
            "PRETTIERD_DEFAULT_CONFIG=%s",
            vim.fn.expand("~/.config/nvim/utils/linter-config/.prettierrc.json")
        ),
    },
}
local languages = {
    -- lua = { stylua },
    typescript = { prettier },
    javascript = { prettier },
    json = { prettier },
    markdown = { prettier },
}
-- efm with error handling (minimal version for Lua formatting only)
local minimal_languages = {
    lua = { stylua },  -- Keep Lua formatting
}

pcall(function()
    lspconfig.efm.setup({
        cmd = { vim.fn.expand("~/.local/share/nvim/mason/bin/efm-langserver") },
        init_options = { documentFormatting = true },
        root_dir = vim.loop.cwd,
        filetypes = { "lua" },  -- Only for Lua
        settings = {
            rootMarkers = { ".git/" },
            lintDebounce = 100,
            languages = minimal_languages,
        },
        single_file_support = true,
    })
end)

-- Customize keymaps
local cmp = require("cmp")
cmp.setup({
    sources = cmp.config.sources({
        { name = 'nvim_lsp' },
        { name = 'buffer' },
    }),
    mapping = cmp.mapping.preset.insert({
        -- `Enter` key to confirm completion
        ["<CR>"] = cmp.mapping.confirm({ select = false }),

        ["<C-Space>"] = cmp.mapping.complete(),

        -- Scroll up and down in the completion documentation
        ["<C-u>"] = cmp.mapping.scroll_docs(-4),
        ["<C-d>"] = cmp.mapping.scroll_docs(4),
    }),
})
