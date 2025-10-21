---@alias db_nbook.SourceName "sqlite"|"clickhouse"|"postgresql"|"redis"

---@class db_nbook.Source
---@field name db_nbook.SourceName
---@field default_query string
---@field matches fun(uri:string):boolean
---@field build_command fun(uri:string, query:string):string?, string?

local sources = {
	require("db-nbook.sources.sqlite"),
	require("db-nbook.sources.clickhouse"),
	require("db-nbook.sources.postgresql"),
	require("db-nbook.sources.redis"),
}

---@type table<db_nbook.SourceName, db_nbook.Source>
local by_name = {}
for _, source in ipairs(sources) do
	by_name[source.name] = source
end

local M = {}

---Detect the matching source name for a URI.
---@param uri string|nil
---@return db_nbook.SourceName|nil
function M.detect(uri)
	if type(uri) ~= "string" or uri == "" then
		return nil
	end

	for _, source in ipairs(sources) do
		if source.matches(uri) then
			return source.name
		end
	end

	return nil
end

---Fetch a source module by name.
---@param name db_nbook.SourceName|nil
---@return db_nbook.Source|nil
function M.get(name)
	if not name then
		return nil
	end

	return by_name[name]
end

---Lookup the default query for a given source.
---@param name db_nbook.SourceName|nil
---@return string
function M.default_query(name)
	local source = M.get(name)
	if source and source.default_query then
		return source.default_query
	end
	return "SELECT 1;"
end

return M
