local snippets = {}

for _, module_name in ipairs({
  "snippets.tex.delimiters",
  "snippets.tex.environments",
  "snippets.tex.math",
  "snippets.tex.math-commands",
  "snippets.tex.commands",
}) do
  local module_snippets = require(module_name)
  if type(module_snippets) ~= "table" then
    error(("TeX snippet module %s must return a table"):format(module_name))
  end
  vim.list_extend(snippets, module_snippets)
end

return snippets
