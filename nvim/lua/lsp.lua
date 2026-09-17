-- Load default lsp-zero keymaps
local lsp_zero = require("lsp-zero")
local telescope = require("telescope.builtin")

-- Install LSP servers automatically through Mason
require("mason").setup()
require("mason-lspconfig").setup()


lsp_zero.on_attach(function(_, bufnr)
    -- see :help lsp-zero-keybindings to learn the available actions
    lsp_zero.default_keymaps({ buffer = bufnr, exclude = { "[d", "]d" } })

    local opts = { buffer = bufnr, remap = false }
    vim.keymap.set("n", "<leader>vc", vim.lsp.buf.code_action, opts)
    vim.keymap.set("n", "<leader>vr", vim.lsp.buf.rename, opts)

    vim.keymap.set("n", "<leader>en", function()
        vim.diagnostic.jump({ count = 1, on_jump = function(_, buffer)
            vim.diagnostic.open_float({ bufnr = buffer })
        end })
    end, opts)
    vim.keymap.set("n", "<leader>ep", function()
        vim.diagnostic.jump({ count = -1, on_jump = function(_, buffer)
            vim.diagnostic.open_float({ bufnr = buffer })
        end })
    end, opts)
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


-- go
vim.lsp.config("golangci_lint_ls", {
    root_markers = {
        "go.mod",
        "go.work",
        ".golangci.yml",
        ".golangci.yaml",
        ".golangci.toml",
        ".golangci.json",
        ".git"
    },
})
vim.lsp.config("gopls", {
    -- Use the self-managed gopls built with the current Go toolchain.
    -- Mason prepends its bin to PATH, otherwise nvim would launch a stale
    -- gopls built with an older Go that cannot type-check newer-Go code.
    cmd = { vim.fn.expand("~/go/bin/gopls") },
    settings = {
        gopls = {
            gofumpt = true,
            staticcheck = true,
        },
    },
})
-- rust
vim.lsp.config("rust_analyzer", {
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
vim.lsp.config("lua_ls", lsp_zero.nvim_lua_ls())
-- C/C++
vim.lsp.config("clangd", {
    cmd = {
        "clangd",
        "--background-index",
        "--clang-tidy",
        "--header-insertion=never", -- avoid automatic imports
    },
    filetypes = { "c", "cpp", "objc", "objcpp", "cuda", "hpp", "cppm", "ixx", "ccm", "cxxm", "c++m" },
})

-- Python
vim.lsp.config("pylsp", {
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
vim.lsp.config("buf_ls", {
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
-- Lua formatting
local minimal_languages = {
    lua = { stylua },  -- Keep Lua formatting
}

vim.lsp.config("efm", {
    cmd = { vim.fn.expand("~/.local/share/nvim/mason/bin/efm-langserver") },
    init_options = { documentFormatting = true },
    root_markers = { ".git" },
    filetypes = { "lua" },
    settings = {
        rootMarkers = { ".git/" },
        lintDebounce = 100,
        languages = minimal_languages,
    },
})

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
