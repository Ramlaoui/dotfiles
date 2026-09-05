local M = {}

function M.split(stripped)
  local depth = 0
  for index = #stripped, 1, -1 do
    local char = stripped:sub(index, index)
    if char == ")" then
      depth = depth + 1
    elseif char == "(" then
      depth = depth - 1
      if depth == 0 then
        return stripped:sub(1, index - 1), stripped:sub(index)
      end
    end
  end
  return nil
end

return M
