return {
	"ggml-org/llama.vim",
	init = function()
		vim.g.llama_config = {
			endpoint_fim = "http://127.0.0.1:8090/infill",
			endpoint_inst = "http://127.0.0.1:8090/v1/chat/completions",
			model_fim = "fim_model",
			model_inst = "inst_model",
		}
	end,
}
